# same args as in all-packages.nix
# should this be moved into pkg/top-level/all-packages.nix ?
{
  system ? builtins.currentSystem
, stdenvType ? system
, bootStdenv ? null
, noSysDirs ? true
, gccWithCC ? true
, gccWithProfiling ? true
, config ? null

# additional:
, nixpkgs ? ../nixpkgs
, ...
}:

/* overview:

   gem nix fetches all known packgaes from default sources (rubygems, gemcutter).
   Those packages are written to nix package list pkgs/ruby-packages.nix.
   resolveRubyPkgDependencies then tries to find dependiencies automatically
   failing if dependency constraints can't be satisfied. A very simple
   implementation is used.

   C libraries (and missing deps) are merged into those attributes.
   (See patches in pkgs/defaults.nix)

   finally the tested attribute contains ruby packgaes which are known to work.

   Of course it should be easy to merge in your own ruby packages..
*/

let

  # stupidly repeating all arguments:
  mainConfig = { inherit system stdenvType bootStdenv noSysDirs gccWithCC gccWithProfiling config; };

  merge = list: (removeAttrs (mergeAttrsByFuncDefaults list) ["mergeAttrBy"]);

  # pkgs, lib, getConfig from nixpkgs:
  pkgs = import nixpkgs mainConfig;
  lib = pkgs.lib;
  getConfig = pkgs.getConfig;

  inherit (builtins) attrNames head tail compareVersions lessThan filter
          hasAttr getAttr toXML isString add;

  inherit (lib) attrSingleton mergeAttrsByFuncDefaults optional listToAttrs
                attrValues concatLists mapAttrs nvs concatStringsSep fold concatStrings;


  # functions contributing to package pool
  inherit (import ../nixpkgs-ruby-overlay-specs mainConfig) specsByPlatformName;
  additionalPackages = (import pkgs/additional-packages.nix) pkgs.fetchurl;

  ### helper functions (reimplementation of gems verion matching)

  tag = pkg:
    let sAT = pkgs.sourceAndTags;
    in sAT.sourceWithTagsDerivation (sAT.sourceWithTagsFromDerivation (sAT.addRubyTagingInfo pkg));

  # version something like ["=" "3.0.4"]
  # spec must have version and bump attributes
  specMatchesVersionConstraint = spec: c:
    let
        dotCount = s: c: if s == "" then c else
          let h = builtins.substring 0 1 s;
              t = builtins.substring 1 9999 s;
          in dotCount t (builtins.add c (if h == "." then 1 else 0));
        # first number is always major. nix's compare function dosen't
        # understand this so append .0 until both versions have the same amount of "."
        add0s = v: is_c: target_c:
          if builtins.lessThan is_c target_c then
            "${add0s v (add is_c 1) target_c}.0"
          else v;

        spec_v = spec.version;
        compare_v = head (tail c);
        spec_c = dotCount spec_v 0;
        compare_c = dotCount compare_v 0;
        spec_v_eq = add0s spec_v spec_c compare_c;
        compare_v_eq = add0s compare_v compare_c spec_c;

        op = head c;
        x = compareVersions spec_v_eq compare_v_eq;
        fs = {
          "="  = x == 0;
          "!=" = x != 0;
          ">"  = lessThan 0 x;
          "<"  = lessThan x 0;
          ">=" = x == 0 || lessThan 0 x;
          "<=" = x == 0 || lessThan x 0;
          "~>" = (lessThan 0 x || x == 0) && lessThan 0 (compareVersions spec.bump compare_v_eq);
        };
     in let r = getAttr op fs;
        in # builtins.trace "${spec.name} ${op} ${compare_v} matches ? ${spec.version} ${if r then "y" else "n"}" 
           r;

  specMatchesVersionConstraints = spec: constraints: lib.all (specMatchesVersionConstraint spec) constraints;

  packageByNameAndConstraints = { specsByPlatformNames
                                , depending ? ""
                                , cn # either ["rake"  [[">=" "0.4.4"]]] or just "rake"
                                , platform ? "ruby"
                                , p ? (x: true) # see resolveRubyPkgDependencies
                                }:
    let specsByPlatformName = platform: name: lib.fold (a: b: b // a) {} (map (f: f platform name) specsByPlatformNames);
        name = if isString cn then cn else head cn;
        constraints = if isString cn then [] else head (tail cn);
        specs = specsByPlatformName platform name;
        sortSpecsByVersion = list: 
          if list == [] 
          then []
          else lib.sort (a: b: builtins.lessThan 0 (builtins.compareVersions a.version b.version)) list;
        matching = lib.filter (spec: p spec && specMatchesVersionConstraints spec constraints) (sortSpecsByVersion (lib.attrValues specs));
    in if matching == [] then throw "no spec satisfying name ${name} after applying filter and constraints. gem requesting dependency: ${depending}"
       else head matching;

  attrsToP = attrs: spec:
    if hasAttr spec.name attrs then specMatchesVersionConstraints spec (getAttr spec.name attrs)
    else true;

  ### default implementation

  ruby_defaults = {ruby, rubygems}:
    pkgs.callPackage pkgs/defaults.nix {
      inherit pkgs ruby rubygems mainConfig;
    };

  # resolves dependencies automatically. Dependencies are taken from the specs
  # fails if two different version of the same package are found in a dependency tree.
  # If this failure happens you have to filter the pool by passing p forcing a
  # specific version.
  #
  # returns: list of derivation. attr names are package names (without version)
  resolveRubyPkgDependencies = { platform ? "ruby",  # platform. ruby tested only.
                                  specsByPlatformNames, # functions taking a platform and a name returning specs by version attrs
                                                         # mandatory keys: name, version, ...
                                  names ? [],   # the packages you'd like to use (list of names or ["name" [[version constraint]]])
                                  patches ? {}, # some dependencies require C extensions
                                  rubyDerivation ? (args: throw "no function specified"), # creates the derivation
                                  p ? (x: true),  # predicate which you can use to exclude versions
                                  forceDeps ? [], # force additional deps - probably causing trouble. disabled
                                  dropDeps ? ["win32-process" "win32-api"] # drop some runtime dependencies which don't make sense on linux
                                                               # TODO there must be a smarter way to do this.
      }:

      assert forceDeps == []; # too experimental

      let 

          nameOf = x: if isString x then x else head x;
          forcedNames =  map nameOf forceDeps;

          # <set of deep dependencies> : { name = { version = derivation ; ... }; ... }

          # merges <set of deep dependencies>
          mergeDeepDeps = lib.mergeAttrsWithFunc (lib.mergeAttrs);

          toDD = name: version: x: nvs name (nvs version x);

          # returns { d =  { name = derivation; }; deepDeps = <set of deep dependencies>; }
          derivationByConstraint = visiting: depending: cn:
            let spec = packageByNameAndConstraints { inherit platform specsByPlatformNames depending cn p; };

                # used in else, calculated lazily:
                patchesList = optional (hasAttr full_name patches) (getAttr full_name patches)
                           ++ optional (hasAttr spec.name patches) (getAttr spec.name patches);
                patched_spec = merge ([spec] ++ patchesList);

                full_name = "${spec.name}-${spec.version}";
                # if don't add forcedDeps to forcedDeps which would result in cyclic depndencies
                forcedDeps = lib.filter (x: !lib.elem (nameOf x) forcedNames) forceDeps;
                cDeps = 
                  lib.filter (x: ! lib.elem (nameOf x) dropDeps)
                         (forcedDeps ++ spec.runtimeDependencies ++ (lib.maybeAttr "additionalRubyDependencies" [] patched_spec));
                deps = derivationsByConstraints ([spec.name] ++ visiting) full_name cDeps;

                args = merge ([patched_spec { propagatedBuildInputs = attrValues deps.d; }]);
                d = rubyDerivation args;

            in if lib.elem spec.name visiting then throw "cyclic dependency ${concatStringsSep "->" visiting}"
               else { d = nvs spec.name d; deepDeps = mergeDeepDeps (toDD spec.name spec.version d) deps.deepDeps; };

          # returns { d = { name1 =  d1, name2 = d2; .. }; deepDeps = <set of deep dependencies>; }
          derivationsByConstraints = visiting: depending: cs:
            fold (a: b: { d = a.d // b.d; deepDeps = mergeDeepDeps a.deepDeps b.deepDeps; })
                 { d = {}; deepDeps = {}; } (map (derivationByConstraint visiting depending) cs);

          resolved = derivationsByConstraints [] "" names;
          many = x: tail x != [];
          trouble = concatLists ( attrValues ( mapAttrs ( name: byV:
                      let versions = attrNames byV;
                      in if many versions then [ "\n${name}: [${lib.concatStringsSep ", " versions}]\n" ]
                          else []) resolved.deepDeps ) );
       in if trouble != []
          then throw "multiple versions selected of the same package name selected by solver. Add constraints manually! ${concatStrings trouble}"
          else resolved;
  # end resolveRubyPkgDependencies
   
  a = rec {

    inherit ruby_defaults;

    rubyPackagesFor = { ruby
                      , rubygems ? null
                      , names ? []
                      , forceDeps ? []
                      , p ? {}
                      , specsByPlatformNames ? [ additionalPackages specsByPlatformName ]
                      }:
      let defaults = ruby_defaults { inherit rubygems ruby; };
          resolved = resolveRubyPkgDependencies {
                      inherit (defaults) patches rubyDerivation;
                      inherit names forceDeps specsByPlatformNames;
                      p = attrsToP p;
                    };
          # all packages of the dependency tree including ruby and rubygems
          allP = concatLists (attrValues (mapAttrs (n: v: attrValues v) resolved.deepDeps))
                ++ lib.optional (rubygems != null) rubygems
                ++ [ ruby ];
          sAT = pkgs.sourceAndTags;
      in {
        # requested packages by name:
        packages = resolved.d;

        # all + with tags
        all = allP;
        tagged = lib.optionals (pkgs.getConfig ["ruby" "tags"] false)
                               (map tag allP);
      };

    rubyPackages18 = args: rubyPackagesFor ({ruby = pkgs.ruby18; inherit (pkgs) rubygems;} // args);
    rubyPackages19 = args: rubyPackagesFor ({ruby = pkgs.ruby19; } // args);


    # usage:
    # rubyEnv [ "sup" "hoe" "rails" ];
    # then you can put the libraries in ENV this way:
    # ruby-env-sup /bin/sh
    rubyEnv = rubyPackagesFor: {name ? "ruby", names ? [], p ? {} }:
      let px = rubyPackagesFor { inherit names p; };
      in pkgs.stdenv.mkDerivation {
        name = "ruby-wrapper-${name}";
        buildInputs = px.all ++ px.tagged;
        tagged = px.tagged;
        unpackPhase = ":";
        installPhase = ''
          ensureDir $out/bin
          b=$out/bin/ruby-env-${name}
          cat >> $b << EOF
          #!/bin/sh
          if [ "$1" == "--clean" ]; then
            shift
            unset RUBYLIB
            unset GEM_PATH
          fi
          export RUBYLIB=$RUBYLIB\''${RUBYLIB:+}\$RUBYLIB
          export GEM_PATH=$GEM_PATH\''${GEM_PATH:+:}\$GEM_PATH
          export PATH=$PATH\''${PATH:+:}\$PATH
          export TAG_FILES=$TAG_FILES\''${TAG_FILES:+:}\$TAG_FILES
          "\$@"
          EOF
          chmod +x $b
        '';
      };

    rubyEnv18 = rubyEnv rubyPackages18;
    rubyEnv19 = rubyEnv rubyPackages19;

    ### RUBY 1.8


    # packages known to work:
    tested18 = rubyPackages18 {
       names = [
          "nokogiri" "rake" "escape"
          "git"
          "hoe"
          "rubyforge"
          "json-pure"
          "chronic"
          "rubygems-update"
          "jeweler"
          "rake"
          "ncursesw"
          "trollop"
          "gettext"
          "locale"
          "lockfile"
          "rmail"
          "highline"
          "net-ssh"
          "mime-types"
          "sup" # curses is distributed with ruby
          "xrefresh-server"
          "rspec"
      ];
    }.packages; 
    ### RUBY 1.9

    # packages known to work:
    tested19 = rubyPackages19 {
       names = [
          "nokogiri" "rake" "escape"
          "git"
          "hoe"
          "rubyforge"
          "json_pure"
          "chronic"
          "jeweler"
          "rake"
          "ncursesw"
          "trollop"
          "gettext"
          "locale"
          "lockfile"
          "rmail"
          "highline"
          "net-ssh"
          "mime-types"
          # "sup" # requires ncurses wich doesn't copmile (?)
          "xrefresh-server"
          "rspec"
          "ffi"
          "xapian-full"
          "ncursesw"
          # "ncurses"
          "rails"
          "bundler"

          # to test
          "ZenTest"
          "rake-compiler"
       ];
    }.packages;

    # simple env enough to run the gem nix command updating the dump
    simpleEnv = rubyEnv19 {
      name = "simple";
      names = ["nixpkgs-ruby-overlay-gem-plugin"];
    };

    # example usage of a ruby environment you can load easily
    railsEnv = rubyEnv19 {
        name = "rails";
        p = {
          # bundler= [["~>" "1.1.2" ]];
          rails  = [["="  "3.0.3" ]]; # rake requires exactly this version ?
          activesupport = [[ "=" "3.0.3" ]];
          builder = [[ "=" "2.1.2" ]];
        };
        names = [
          "rake" "rails" 
          "bundler"
          "builder"
          "haml"

          # comomnly used databases
          "sqlite3-ruby"

          # tool
          "haml"
          "sinatra"
        ];
    };

    inherit resolveRubyPkgDependencies;

    previewDerivation = spec:
      pkgs.runCommand "${spec.name}-source-preview" {} ''
        ensureDir $out
        cd $out
        tar xf ${spec.src}
        tar xfz data.tar.gz
      '';

    # usage: cd $(GEM="$1" nix-build -A ro.preview $NIXPKGS_ALL --no-out-link )
    preview =
      let spec = packageByNameAndConstraints { inherit specsByPlatformName;  cn = builtins.getEnv "GEM"; };
      in  previewDerivation spec;

    taggingTest = tag pkgs.ruby19;

  };

in a
