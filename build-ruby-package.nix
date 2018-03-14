{pkgs, ruby, patches_by_name}:

let
    setupHook = ''
      THIS_RUBY_LIB=$(echo $out/gems/*/lib)
      THIS_GEM_PATH=$out

      cat >> $out/nix-support/setup-hook << EOF 
        declare -A RUBYLIB_HASH # using bash4 hashs
        declare -A GEM_PATH_HASH # using bash4 hashs

        if [ -n "$THIS_RUBY_LIB" ]; then
          RUBYLIB_HASH["$THIS_RUBY_LIB"]=
        fi
        for path in \''${!RUBYLIB_HASH[@]}; do
          export RUBYLIB=\''${RUBYLIB}\''${RUBYLIB:+:}\$path
        done
        GEM_PATH_HASH["$THIS_GEM_PATH"]=
        for path in \''${!GEM_PATH_HASH[@]}; do
          export GEM_PATH=\''${GEM_PATH}\''${GEM_PATH:+:}\$path
        done
      EOF
      . $out/nix-support/setup-hook
    '';

    rubygems = null;

in

rpkgs: pkg:

    let full_name = "${pkg.name}-${pkg.version}";
        patch = pkgs.lib.mergeAttrsByFuncDefaults ( patches_by_name { inherit (pkg) name; full_name = "${pkg.name}-${pkg.version}"; } );
        inherit (pkgs) lib;
        gemCommand = patch.gemCommand or ''
          echo gem install --backtrace -V --ignore-dependencies -i "$out" "$src" $gemFlags -- $buildFlags
          gem install --backtrace -V --ignore-dependencies -i "$out" "$src" $gemFlags -- $buildFlags
        '';
        completeArgs = (pkgs.lib.mergeAttrsByFuncDefaults
        ([
          pkg
          {
            buildInputs =
              [ruby pkgs.makeWrapper] 
              ++ lib.optional (rubygems != null) rubygems ;
            propagatedBuildInputs =
              map (name: rpkgs.${name}) pkg.dependencies;
            unpackPhase = ":";
            configurePhase=":";
            bulidPhase=":";

            # TODO add some abstraction for this kind of env path concatenation. It's used multiple times
            installPhase = ''
              mkdir -p "$out/nix-support"
              export HOME=$TMP/home; mkdir "$HOME"

              ${gemCommand}
              rm -fr $out/cache # don't keep the .gem file here

              ${setupHook}

              for prog in $out/bin/*; do
                if ! [ -d "$prog" ]; then
                   p="$(dirname "$(dirname "$prog")")"/bin-wrapped/
                   mkdir -p "$p" || true
                   hidden="$p"/"$(basename "$prog")"
                   mv "$prog" "$hidden"
                   # Using makeWrapper for puppet use case
                   # It expects the wrapped command to have the same name
                   makeWrapper "$hidden" "$prog" \
                     --prefix RUBYLIB : "$RUBYLIB"${ if rubygems == null then "" else ":${rubygems}/lib" } \
                     --prefix GEM_PATH : "$GEM_PATH" \
                     --set RUBYOPT 'rubygems'
                fi
              done

              for prog in $out/gems/*/bin/* $out/gems/*/bin/*/*; do
                # there is rails-2.3.5/gems/rails-2.3.5/bin/performance/* thus use */* :-(
                # should be using find here?
                [ -d "$prog" ] && continue || true

                [ -e "$out/bin/$(basename $prog)" ] && continue || true
                sed -i '1s@.*@#!  ${ruby}/bin/ruby@' "$prog"
                t="$out/bin/$(basename "$prog")"
                cat >> "$t" << EOF
              #!/bin/sh
              export GEM_PATH=$GEM_PATH:\$GEM_PATH
              #export RUBYLIB=$RUBYLIB:\$RUBYLIB
              exec $(type -p ruby) $prog "\$@"
              EOF
                chmod +x "$t"
              done

              runHook postInstall
            '';
        }
        patch
        { name = "${pkg.name}-${pkg.version}"; }
        ]
      ));
    in
      let args = (removeAttrs completeArgs ["mergeAttrBy"]);
      in pkgs.stdenv.mkDerivation args
