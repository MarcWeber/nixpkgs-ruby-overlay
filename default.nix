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
}:

/* overview:

   gem nix fetches all known packgaes from default sources (rubygems, gemcutter).
   Those packages are written to nix package list pkgs/defaults.nix.
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

  inherit (builtins) attrNames head tail compareVersions lessThan filter hasAttr getAttr toXML;

  inherit (lib) attrSingleton mergeAttrsByFuncDefaults optional listToAttrs;

  ruby_defaults = {ruby, rubygems}:
    pkgs.callPackage pkgs/defaults.nix {
      inherit pkgs ruby rubygems;
    };

  # roselves dependencies automatically ensuring that only one version of a
  # library is present in the dependency chain by ignoring all "older" versions
  # of a package. So this KISS solver is likely miss some valid solutions which
  # reqiure older package versions
  #
  # returns: list of derivation. attr names are package names (without version)
  resolveRubyPkgDependencies = { platform ? "ruby",  # platform. ruby tested only.
                                  rubyPackages ? {},     # dict like pkgs/ruby-packages.nix
                                                         # mandatory keys: name, version, ...
                                  names ? [],   # the packages you'd like to use (list of names)
                                  patches ? {}, # some dependencies require C extensions
                                  rubyDerivation ? (args: throw "no function specified") # creates the derivation
      }:

    let latestPkg = list: builtins.head (lib.sort (a: b: builtins.compareVersions a.version b.version) list);

        # result is attrs containing package names only
        latestByName = listToAttrs ( lib.mapAttrsFlatten
                            (pkg_name : attr:
                              let latest = latestPkg (lib.attrValues attr);
                              in  { name = latest.name;
                                    value = latest;
                                  }
                            ) (getAttr platform rubyPackages) );

        pkgByName = depending: name: lib.maybeAttr name (throw "couldn't find ruby dependency named ${name} required by ${depending}") latestByName;

        pkgByConstraints = depending: p:
          let name = head p;
              constraints = head (tail p);
              pkg = pkgByName depending name;
              match = op_version:
                let op = head op_version;
                    v = head (tail op_version);
                    x = compareVersions pkg.version v;
                    fs = {
                      "="  = x == 0;
                      "!=" = x != 0;
                      ">"  = lessThan 0 x;
                      "<"  = lessThan x 0;
                      ">=" = x == 0 || lessThan 0 x;
                      "<=" = x == 0 || lessThan x 0;
                      "~>" = lessThan 0 x && lessThan 0 (compareVersions pkg.bump v);
                    };
                in getAttr op fs;
          failing = lib.filter (x: !(match x)) constraints;

          in if failing ==[] then pkg else (throw "couldn't satisfy all contstraints of depndency ${name} reqiured by ${depending}: ${toXML failing}");

        makeDerivation =
              making: # list of names being visited to prevent cyclic dependencies
              pkg_descr:
          let full_name = "${pkg_descr.name}-${pkg_descr.version}";
              patchesList = optional (hasAttr full_name patches) (getAttr full_name patches)
                     ++ optional (hasAttr pkg_descr.name patches) (getAttr pkg_descr.name patches);
              patched_descr = merge ([pkg_descr] ++ patchesList);
              nameToConstraint = f: [f []];
              ruby_deps = patched_descr.runtimeDependencies 
                          ++ (map nameToConstraint (lib.maybeAttr "additionalRubyDependencies" [] patched_descr));
              making_new = making ++ [pkg_descr.name];
              deps_derivations = map (x: makeDerivation making_new (pkgByConstraints pkg_descr.name x)) ruby_deps;

          in if  lib.elem pkg_descr.name making then throw "cyclic dependency ${toXML making} -> ${pkg_descr.name}"
              else rubyDerivation (merge [ patched_descr { propagatedBuildInputs = deps_derivations; } ]);

    in listToAttrs (map (name: { inherit name; value = makeDerivation [] (pkgByName "<user>" name); } ) names)
  ; # end resolveRubyPkgDependencies
   
  a = rec {

    inherit ruby_defaults;

    rubyPackages18 = names:
      let defaults = ruby_defaults {inherit (pkgs) ruby rubygems;};
      in resolveRubyPkgDependencies {
        inherit (defaults) rubyPackages patches rubyDerivation;
        inherit names;
      };

    # packages known to work:
    tested18 = rubyPackages18 [
          "nokogiri" "rake" "escape"
          "git"
          "hoe"
          "rubyforge"
          "json_pure"
          "chronic"
          "rubygems_update"
          "jeweler"
          "rake"
          "ncursesw"
          "trollop"
          "gettext"
          "locale"
          "lockfile"
          "rmail"
          "highline"
          "net_ssh"
          "mime_types"
          "sup" # curses is distributed with ruby
          "xrefresh-server"
    ];

    inherit resolveRubyPkgDependencies;

  };

in a
