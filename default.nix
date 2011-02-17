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

  inherit (builtins) attrNames head tail compareVersions lessThan filter hasAttr getAttr toXML isString;

  inherit (lib) attrSingleton mergeAttrsByFuncDefaults optional listToAttrs
                attrValues concatLists mapAttrs nvs concatStringsSep fold concatStrings;


  ### helper functions (reimplementation of gems verion matching)
  # version something like ["=" "3.0.4"]
  # spec must have version and bump attributes
  specMatchesVersionConstraint = spec: c:
    let
        op = head c;
        v = head (tail c);
        x = compareVersions spec.version v;
        fs = {
          "="  = x == 0;
          "!=" = x != 0;
          ">"  = lessThan 0 x;
          "<"  = lessThan x 0;
          ">=" = x == 0 || lessThan 0 x;
          "<=" = x == 0 || lessThan x 0;
          "~>" = (lessThan 0 x || x == 0) && lessThan 0 (compareVersions spec.bump v);
        };
     in getAttr op fs;

  specMatchesVersionConstraints = spec: constraints: lib.all (specMatchesVersionConstraint spec) constraints;

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
                                  specsByPlatformName ? {}, # function taking a platform and a name returning specs by version attrs
                                                         # mandatory keys: name, version, ...
                                  names ? [],   # the packages you'd like to use (list of names or ["name" [[version constraint]]])
                                  patches ? {}, # some dependencies require C extensions
                                  rubyDerivation ? (args: throw "no function specified"), # creates the derivation
                                  p ? (x:true)  # predicate which you can use to exclude versions
      }:

      let 
          packageByNameAndConstraints = depending: name: constraints:
            let specs = specsByPlatformName platform name;
                sortSpecsByVersion = list: lib.sort (a: b: builtins.compareVersions a.version b.version) list;
                matching = lib.filter (spec: p spec && specMatchesVersionConstraints spec constraints) (sortSpecsByVersion (lib.attrValues specs));
            in if matching == [] then throw "no spec satisfying name ${name} after applying filter and constraints ${depending}" else head matching;

          # <set of deep dependencies> : { name = { version = derivation ; ... }; ... }

          nameToConstraint = p: if isString p then [p []] else p;

          # merges <set of deep dependencies>
          mergeDeepDeps = lib.mergeAttrsWithFunc (lib.mergeAttrs);

          toDD = name: version: x: nvs name (nvs version x);

          # returns { d =  { name = derivation; }; deepDeps = <set of deep dependencies>; }
          derivationByConstraint = visiting: depending: c:
            let spec = packageByNameAndConstraints depending (nameToConstraint c);

                # used in else, calculated lazily:
                patchesList = optional (hasAttr full_name patches) (getAttr full_name patches)
                           ++ optional (hasAttr spec.name patches) (getAttr spec.name patches);
                patched_spec = merge ([spec] ++ patchesList);

                full_name = "${spec.name}-${spec.version}";
                cDeps = spec.runtimeDependencies ++ map (nameToConstraint) (lib.maybeAttr "additionalRubyDependencies" [] patched_spec);
                deps = derivationsByConstraints ([spec.name] ++ visiting) spec.name cDeps;

                d = rubyDerivation (merge ([spec { propagatedBuildInputs = attrValues deps.d; }] ++ patchesList));

            in if lib.elem spec.name visiting then throw "cyclic dependency ${concatStringsSep "->" visiting}"
               else { inherit d; deepDeps = mergeDeepDeps (toDD spec.name spec.version d) deps.deepDeps; };

          # returns { d = { name1 =  d1, name2 = d2; .. }; deepDeps = <set of deep dependencies>; }
          derivationsByConstraints = visiting: depending: cs:
            fold (a: b: { d = a.d // b.d; deepDeps = mergeDeepDeps a.deepDeps b.deepDeps; })
                 {} (map derivationByConstraint names);

          resolved = derivationsByConstraints [] "" names;
          many = x: tail x != [];
          trouble = concatLists ( attrValues ( mapAttrs ( name: byV:
                      let versions = attrNames byV;
                      in if many versions then [ "\n${name}: [${lib.concatStringsSep ", " versions}]\n" ]
                          else []) resolved.deepDeps ) );
       in if trouble != []
          then throw "multiple versions selected of the same package name selected by solver. Add constraints manually! ${concatStrings trouble}"
          else resolved.d;
  # end resolveRubyPkgDependencies
   
  a = rec {

    inherit ruby_defaults;

    ### RUBY 1.8

    rubyPackages18 = names:
      let defaults = ruby_defaults {
        inherit (pkgs) rubygems;
        ruby = pkgs.ruby18;
      };
      in resolveRubyPkgDependencies {
        inherit (defaults) specsByPlatformName patches rubyDerivation;
        inherit names;
      };

    # usage:
    # rubyEnv "sup" pkgs.ruby18 (tested18.sup.buildInputs ++ tested18.sup.propagatedBuildInputs)
    # then you can put the libraries in ENV this way:
    # ruby-env-sup /bin/sh
    rubyEnv = name: ruby: packages: pkgs.stdenv.mkDerivation {
      name = "ruby-wrapper-${name}";
      buildInputs = [ruby] ++ packages;
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
        # export PATH=${ruby}/bin\''${PATH:+:}\$PATH
        export PATH=$PATH\''${PATH:+:}\$PATH
        "\$@"
        EOF
        chmod +x $b
      '';
    };

    # packages known to work:
    tested18 = rubyPackages18 [
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

    ### RUBY 1.9

    rubyPackages19 = names:
      let defaults = ruby_defaults {
        rubygems = null; # is built into ruby-1.9
        ruby = pkgs.ruby19;
      };
      in resolveRubyPkgDependencies {
        inherit (defaults) specsByPlatformName patches rubyDerivation;
        inherit names;
      };

    # packages known to work:
    tested19 = rubyPackages19 [
          "nokogiri" "rake" "escape"
          "git"
          "hoe"
          "rubyforge"
          "json-pure"
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

    # example usage of a ruby environment you can load easily
    railsEnv = rubyEnv "rails-env" pkgs.ruby19 (lib.attrValues (rubyPackages19 
          [ "rake" "rails" "bundler"

          # comomnly used databases
          "sqlite3-ruby"

          # tool
          "haml"
          "sinatra"
          ]
          ));

    inherit resolveRubyPkgDependencies;

  };

in a
