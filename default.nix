# same args as in all-packages.nix
# should this be moved into pkg/top-level/all-packages.nix ?
mainArgs@{
  system ? builtins.currentSystem
, bootStdenv ? null
, noSysDirs ? true
, gccWithCC ? true
, gccWithProfiling ? true
, config ? null

# additional:
, nixpkgs ? ../nixpkgs
, ...
}:

let

  pkgs = import <nixpkgs> mainArgs;

  patches_by_ruby = ruby: import ./patches.nix { inherit ruby pkgs; };

  patches_by_name_fun = {ruby}: a@{name, full_name}:
    let patches = patches_by_ruby ruby;
    in
        pkgs.lib.optional (patches ? ${name}) patches.${name}
        ++ pkgs.lib.optional (patches ? ${full_name}) patches.${full_name};


  packages = {ruby, pkgs_fun, patches_by_name}:
    let build_ruby_package = import ./build-ruby-package.nix { inherit pkgs ruby patches_by_name;};
    in pkgs_fun { inherit build_ruby_package; inherit (pkgs.lib) fix; inherit (pkgs) fetchurl; };

  tag = pkg:
    let sAT = pkgs.sourceAndTags;
    in sAT.sourceWithTagsDerivation (sAT.sourceWithTagsFromDerivation (sAT.addRubyTaggingInfo pkg));

    # usage:
    # rubyEnv [ "sup" "hoe" "rails" ];
    # then you can put the libraries in ENV this way:
    # ruby-env-sup /bin/sh
    rubyEnv = { name, ruby, pkgs_fun }:
        let
          attrs = packages { inherit ruby; patches_by_name = patches_by_name_fun {inherit ruby; }; inherit pkgs_fun; };
        in pkgs.stdenv.mkDerivation {
          name = "ruby-wrapper-${name}";
          buildInputs = 
            let p = builtins.attrValues attrs;
            in [ruby] ++ p ++ (map tag p);
          # tagged = px.tagged;
          unpackPhase = ":";
          installPhase = ''
            mkdir -p $out/bin
            b=$out/bin/ruby-env-${name}
            cat >> $b << EOF
            #!/bin/sh
            if [[ "\$1" == "--clean" ]]; then
              shift
              unset RUBYLIB
              unset GEM_PATH
            fi
            export RUBYLIB=$RUBYLIB\''${RUBYLIB:+:}\$RUBYLIB
            export GEM_PATH=$GEM_PATH\''${GEM_PATH:+:}\$GEM_PATH
            export PATH=$PATH\''${PATH:+:}\$PATH
            export TAG_FILES=$TAG_FILES\''${TAG_FILES:+:}\$TAG_FILES
            "\$@"
            EOF
            chmod +x $b
          '';
        };

in {

  inherit packages patches_by_name_fun rubyEnv;
  # test = let ruby = pkgs.ruby_2_3; in packages { inherit ruby; patches_by_name = patches_by_name_fun {inherit ruby; }; pkgs_fun = import ./test.nix; };
  testEnv = rubyEnv { name = "test"; pkgs_fun = import ./collections/test.nix; ruby = pkgs.ruby_2_3; };
}
