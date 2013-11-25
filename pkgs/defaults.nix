{writeScript, pkgs, ruby, rubygems, mainConfig}:

let inherit (pkgs) fetchurl stdenv lib;
    inherit (pkgs.lib) mergeAttrsByFuncDefaults optional;
    inherit (builtins) hasAttr getAttr;

in rec {

  patchUsrBinEnv = writeScript "path-usr-bin-env" ''
    #!/bin/sh
    set -x
    echo "==================="
    find "$1" -type f -name "*.rb" | xargs sed -i "s@/usr/bin/env@$(type -p env)@g"
    find "$1" -type f -name "*.mk" | xargs sed -i "s@/usr/bin/env@$(type -p env)@g"
  '';

  # these settings are merged into the automatically generated settings
  # either the nameNoVersion or name must match
  # does it make a difference whether you use ruby 1.8 or ruby 1.9 ? Probably yes
  patches = {

    builder = { gemFlags = "--no-ri --no-rdoc"; };
    ffi = {
      postUnpack = "onetuh";
      additionalRubyDependencies = [ "rake" ];
      buildInputs = [ pkgs.libffi ];
      buildFlags=["--with-ffi-dir=${pkgs.libffi}"];
      NIX_POST_EXTRACT_FILES_HOOK = patchUsrBinEnv;
    };

    "HTTP-Live-Video-Stream-Segmenter-and-Distributor" = {
      buildInputs = with pkgs; [ ffmpeg zlib bzip2 x264 lame faad2 ];
      # should be a gem
      installPhase = ''
        unset unpackPhase
        unpackPhase
        cd $sourceRoot
        ensureDir $out/bin
        ensureDir $out/lib

        export RUBYLIB=$RUBYLIB:$out/lib

        find
        mv hs_transfer.rb hs_encoder.rb hs_config.rb $out/lib
        mv example-configs $out

        mv http_streamer.rb $out/bin

        make
        cp live_segmenter $out/bin

        t=$out/bin/http_streamer
        cat >> $t << EOF
        #!/bin/sh
        export RUBYLIB=$out/lib:\$RUBYLIB
        exec $(type -p ruby) $out/bin/http_streamer.rb "\$@"
        EOF
        chmod +x "$t"
      '';
    };

    libv8 = {
      buildInputs = [ pkgs.which ] ++ pkgs.v8.nativeBuildInputs ++ pkgs.v8.propagatedNativeBuildInputs;


      NIX_POST_EXTRACT_FILES_HOOK = writeScript "path-bin" ''
        #!/bin/sh
        set -x
        find "$1" -type f -perm -o+rx | xargs sed -i "s@/usr/bin/env@$(type -p env)@g"
      '';
    };

    linecache19 = {
      # preConfigure = ''
      #   PATH=${ruby.hidden}/bin:$PATH
      # '';
      buildFlags = [ "--with-ruby-include=${ruby}/include"];
    };
    "ruby-debug-base19" = { buildFlags = [ "--with-ruby-include=${ruby}/src"]; };


    mysql = {
      buildInputs = [ pkgs.mysql pkgs.zlib ];
    };
    mysqlplus = {
      buildInputs = [ pkgs.mysql pkgs.zlib ];
    };
    do_mysql = {
      buildInputs = [ pkgs.mysql pkgs.zlib ];
    };

    ncurses = { buildInputs = [ pkgs.ncurses ]; };
    ncursesw = { buildInputs = [ pkgs.ncurses ]; };
    nokogiri = {
      buildFlags=["--with-xml2-dir=${pkgs.libxml2} --with-xml2-include=${pkgs.libxml2}/include/libxml2"
                  "--with-xslt-dir=${pkgs.libxslt}" ];
    };

    do_postgres = {
      buildInputs = [ pkgs.postgresql ];
    };

    postgres = {
      buildInputs = [ pkgs.postgresql ];
    };

    pry.gemFlags = [ "--no-ri" "--no-rdoc" ]; # docs fail 

    psych = { buildInputs = [ pkgs.libyaml ]; };

    rdoc = {
      gemFlags =[ "--no-ri" "--no-rdoc" ]; # can't bootstrap itself yet (TODO)
    };

    rmagick = let im = pkgs.imagemagick; in {
      # is imagemagick enough
      buildInputs = [ im pkgs.pkgconfig ];
      buildFlags = [
        "--without-opt-include=${im}/include/ImageMagick/wand"
        "--without-opt-lib=${im}/lib"
      ];
    };

    rubyuno = {

    };

    rugged = {
      buildInputs = [ pkgs.libgit2 pkgs.zlib pkgs.which ];
      buildFlags = [
        "--without-opt-include=${pkgs.libgit2}/include"
        "--without-opt-lib=${pkgs.libgit2}/lib"
      ];
    };

    "do_sqlite3" = { buildInputs = [ pkgs.sqlite ]; };

    "sqlite3" = { 
      buildInputs = [ pkgs.sqlite ];
      # buildFlags = [ "--with-sqlite3-dir=${pkgs.sqlite}" "--with-sqlite3-include=${pkgs.sqlite}/include" "--with-sqlite3-lib=${pkgs.sqlite}/lib" ];
    };
    sqlite3_ruby = { propagatedBuildInputs = [ pkgs.sqlite ]; };


    sup = {
      additionalRubyDependencies = ["ncursesw"];
      buildInputs = [ (pkgs.xapianBindings.override { inherit ruby; }) ];
    };

    tarruby = {
      buildInputs = [ pkgs.libtar pkgs.zlib ];

      NIX_CFLAGS_COMPILE="-fPIC";

      # buildFlags = [
      #   "--without-opt-include=${pkgs.libtar}/include"
      #   "--without-opt-lib=${pkgs.libtar}/lib"
      # ];
    };

    # rails = {
    #   gemFlags = [ "--no-rdoc" ]; # fails with sed symlink
    # };
    rails = {
      gemFlags = "--no-ri --no-rdoc";
      # additionalRubyDependencies = [ "mime_types" ];
      propagatedBuildInputs = [ /*libs.mime_types libs.rake */ ];
    };

    "ruby-debug19" = { buildFlags = [ "--with-ruby-include=${ruby}/src" ]; };

    "xrefresh-server" =
      let patch = fetchurl {
          url = "http://mawercer.de/~nix/xrefresh.diff.gz";
          sha256 = "1f7bnmn1pgkmkml0ms15m5lx880hq2sxy7vsddb3sbzm7n1yyicq";
        };
      in {
        additionalRubyDependencies = [ "rb-inotify" ];

        # monitor implementation for Linux
        postInstall = ''
          cd $out/gems/*;
          cat ${patch} | gunzip | patch -p 1;
        '';
      };


    "xapian-ruby" = {
      gemFlags = [ "--no-rdoc" ]; # compiling for ruby1.9 fails with: ERROR:  While executing gem ... (Encoding::UndefinedConversionError) U+2019 from UTF-8 to US-ASCII
      additionalRubyDependencies = [ "rake" "rdoc" ];
      buildInputs = [ pkgs.zlib pkgs.libuuid ];


      NIX_POST_EXTRACT_FILES_HOOK = writeScript "path-bin" ''
        #!/bin/sh
        set -x
        sed -i "/ENV..LDFLAGS/d" $out/*/*/Rakefile
        find "$1" -type f -name "*.rb" | xargs sed -i "s@/bin/sed@$(type -p sed)@g"
      '';
    };
    "xapian-full" = {
      gemFlags = [ "--no-rdoc" ]; # compiling for ruby1.9 fails with: ERROR:  While executing gem ... (Encoding::UndefinedConversionError) U+2019 from UTF-8 to US-ASCII
      additionalRubyDependencies = [ "rake" "rdoc" ];
      buildInputs = [ pkgs.zlib pkgs.libuuid ];


      NIX_POST_EXTRACT_FILES_HOOK = writeScript "path-bin" ''
        #!/bin/sh
        set -x
        sed -i "/ENV..LDFLAGS/d" $out/*/*/Rakefile
        find "$1" -type f -name "*.rb" | xargs sed -i "s@/bin/sed@$(type -p sed)@g"
      '';
    };
    "xapian" = {
      gemFlags = [ "--no-rdoc" ]; # compiling for ruby1.9 fails with: ERROR:  While executing gem ... (Encoding::UndefinedConversionError) U+2019 from UTF-8 to US-ASCII
      additionalRubyDependencies = [ "rake" "rdoc" ];
      buildInputs = [ pkgs.xapian  pkgs.gnused pkgs.libtool ];

      NIX_POST_EXTRACT_FILES_HOOK = writeScript "path-bin" ''
        #!/bin/sh
        set -x
        find "$1" -type f -name "*.rb" | xargs sed -i "s@/bin/sed@$(type -p sed)@g"
      '';

    };

  };


  rubyDerivation = args :
    let full_name = "${args.name}-${args.version}";
        completeArgs = (mergeAttrsByFuncDefaults
        ([
          {
            buildInputs = [ruby pkgs.makeWrapper] ++ lib.optional (rubygems != null) rubygems;
            unpackPhase = ":";
            configurePhase=":";
            bulidPhase=":";

            # TODO add some abstraction for this kind of env path concatenation. It's used multiple times
            installPhase = ''
              ensureDir "$out/nix-support"
              export HOME=$TMP/home; mkdir "$HOME"

              gem install --backtrace -V --ignore-dependencies -i "$out" "$src" $gemFlags -- $buildFlags
              rm -fr $out/cache # don't keep the .gem file here

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
        args 
        { name = "${args.name}-${args.version}"; }
      ]
      ));
    in
      let args = (removeAttrs completeArgs ["mergeAttrBy"]);
      in stdenv.mkDerivation args;

}
