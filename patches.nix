{ pkgs, ruby }:

# check .out

let
  patchUsrBinEnv = pkgs.writeScript "path-usr-bin-env" ''
    #!/bin/sh
    set -x
    echo "==================="
    find "$1" -type f -name "*.rb" | xargs sed -i "s@/usr/bin/env@$(type -p env)@g"
    find "$1" -type f -name "*.mk" | xargs sed -i "s@/usr/bin/env@$(type -p env)@g"
  '';

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

  mysql = pkgs.mysql55; # default in nixos could be aria

  in

{

    builder = { gemFlags = "--no-ri --no-rdoc"; };

    ffi = {
      postUnpack = "onetuh";
      additionalRubyDependencies = [ "rake" ];
      buildInputs = [pkgs.libffi.dev pkgs.libffi.out ];
      buildFlags=["--with-ffi-dir=${pkgs.libffi}"];
      NIX_POST_EXTRACT_FILES_HOOK = patchUsrBinEnv;
    };

    "HTTP-Live-Video-Stream-Segmenter-and-Distributor" = {
      buildInputs = with pkgs; [ ffmpeg.out zlib.out bzip2.out x264.out lame.out faad2.out ];
      # should be a gem
      installPhase = ''
        unset unpackPhase
        unpackPhase
        cd $sourceRoot
        mkdir -p $out/bin
        mkdir -p $out/lib

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
      buildInputs = [ pkgs.which ] ++ pkgs.v8.nativeBuildInputs.out ++ pkgs.v8.propagatedNativeBuildInputs.out;


      NIX_POST_EXTRACT_FILES_HOOK = pkgs.writeScript "path-bin" ''
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


    tiny_tds.buildInputs = [ pkgs.freetds ];

    # not maintained anymore, switch to mysql2, please
    mysql.buildInputs = [ mysql pkgs.zlib.out  pkgs.openssl.out];

    mysql2.buildInputs = [ mysql pkgs.zlib.out pkgs.openssl.out ];
    mysqlplus = {
      buildInputs = [ mysql pkgs.zlib.out pkgs.openssl.out ];
    };
    do_mysql = {
      buildInputs = [ mysql pkgs.zlib.out pkgs.openssl.out ];
    };

    curses =  { buildInputs = [ pkgs.ncurses.dev pkgs.ncurses.out ]; };
    ncurses =  { buildInputs = [ pkgs.ncurses.dev pkgs.ncurses.out ]; };
    ncursesw = { buildInputs = [ pkgs.ncurses.dev pkgs.ncurses.out ]; }; 
    "ncursesw-1.4.9" =
    let version ="1.4.9";
        gemspec = pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/sup-heliotrope/ncursesw-ruby/master/ncursesw.gemspec";
          sha256 = "146s9vgrxc9g6s8bi7408szkw98apl8m87lkbqk5km58vp6ypnhb";
        };
    in {
      # buildPhase = "gem build ncursesw.gemspec";

      gemCommand = ''
        set -x
        type -p install

        mkdir $TMP/t
        cat >> $TMP/t/install << EOF
        #!/bin/sh
        echo "==> running" $(type -p install) "$@"
        $(type -p install) "$@" || exit 1
        EOF
        chmod +x $TMP/t/install
        PATH=$TMP/t:$PATH

        gem install --no-verbose --install-dir "$out" \
            --bindir "$out/bin" --no-rdoc --no-ri "$src" || true

        mkdir -p $out/specifications
        cp ${gemspec} $out/specifications/

        cd "$out/gems/ncursesw-${version}"
        mkdir src
        cp -a lib src
        mv *.h src
        sed -i "s/srcdir = ./srcdir = src/" Makefile
        make install

        ${setupHook}
        exit 0
      '';

    };
    nokogiri = {
      buildFlags=[
                  "--with-xml2-include=${pkgs.libxml2.dev}/include/libxml2"
                  "--with-xml2-lib=${pkgs.libxml2.out}/lib"
                  "--with-zlib-include=${pkgs.zlib.dev}/include"
                  "--with-zlib-lib=${pkgs.zlib.out}/lib"
                  "--with-xslt-include=${pkgs.libxslt.dev}/include"
                  "--with-xslt-lib=${pkgs.libxslt.out}/lib"
      ];
    };

    do_postgres = {
      buildInputs = [ pkgs.postgresql.out ];
    };

    postgres = {
      buildInputs = [ pkgs.postgresql.out ];
    };

    pry.gemFlags = [ "--no-ri" "--no-rdoc" ]; # docs fail 

    psych = { buildInputs = [ pkgs.libyaml.out ]; };

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

    rubyuno = { };

    rugged = {
      buildInputs = [ pkgs.libgit2 pkgs.zlib.out pkgs.which ];
      buildFlags = [
        "--without-opt-include=${pkgs.libgit2}/include"
        "--without-opt-lib=${pkgs.libgit2}/lib"
      ];
    };

    "do_sqlite3" = { buildInputs = [ pkgs.sqlite.out pkgs.sqlite.dev ]; };

    "sqlite3" = {
      buildInputs = [ pkgs.sqlite.out pkgs.sqlite.dev ];
      buildFlags = [
        "--with-sqlite3-include=${pkgs.sqlite}/include"
        "--with-sqlite3-lib=${pkgs.sqlite.out}/lib"
      ];
    };
    sqlite3_ruby = { propagatedBuildInputs = [ pkgs.sqlite.out pkgs.sqlite.dev ]; };

    sup = {
      additionalRubyDependencies = ["ncursesw" "xapian-full"/*required for building native extension?*/ ];
      buildInputs = [ (pkgs.xapianBindings.override { inherit ruby; }) pkgs.xapian ];
    };

    mini_mime.patchPhase = ''
        mkdir -p $out/bin
        cat > $out/bin/console << EOF
        #!/bin/sh
        exec $(echo $out/gems/mini_mime-1.0.1/bin/console) "$@"
        EOF
        chmod +x $out/bin/console
    '';

    tarruby = {
      buildInputs = [ pkgs.libtar.out pkgs.zlib.out ];

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

    "public_suffix" = {
      # it looks like /bin/console is run while compiling, so put it where it should be
      patchPhase = ''
        mkdir -p $out/bin
        cat > $out/bin/console << EOF
        #!/bin/sh
        exec $out/gems/public_suffix-3.0.2/bin/console "$@"
        EOF
        chmod +x $out/bin/console
      '';
    };

    "xrefresh-server" =
      let patch = pkgs.fetchurl {
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
      buildInputs = [ pkgs.zlib.dev pkgs.zlib.out pkgs.libuuid.dev pkgs.libuuid.out pkgs.rake ];


#       NIX_POST_EXTRACT_FILES_HOOK = pkgs.writeScript "path-bin" ''
#         #!/bin/sh
#         set -x
#         echo 1
#         sed -i "/ENV..LDFLAGS/d" $out/*/*/Rakefile
#         echo 2
#         find "$1" -type f -name "*.rb" | xargs sed -i "s@/bin/sed@$(type -p sed)@g"
#       '';
    };
    "xapian-full" = {
      gemFlags = [ "--no-rdoc" ]; # compiling for ruby1.9 fails with: ERROR:  While executing gem ... (Encoding::UndefinedConversionError) U+2019 from UTF-8 to US-ASCII
      additionalRubyDependencies = [ "rake" "rdoc" ];
      buildInputs = [ pkgs.zlib.out pkgs.libuuid.out ];


      NIX_POST_EXTRACT_FILES_HOOK = pkgs.writeScript "path-bin" ''
        #!/bin/sh
        set -x
        sed -i "/ENV..LDFLAGS/d" $out/*/*/Rakefile
        find "$1" -type f -name "*.rb" | xargs sed -i "s@/bin/sed@$(type -p sed)@g"
      '';
    };
    "xapian" = {
      gemFlags = [ "--no-rdoc" ]; # compiling for ruby1.9 fails with: ERROR:  While executing gem ... (Encoding::UndefinedConversionError) U+2019 from UTF-8 to US-ASCII
      additionalRubyDependencies = [ "rake" "rdoc" ];
      buildInputs = [ pkgs.xapian.out  pkgs.gnused pkgs.libtool.out ];

      NIX_POST_EXTRACT_FILES_HOOK = pkgs.writeScript "path-bin" ''
        #!/bin/sh
        set -x
        find "$1" -type f -name "*.rb" | xargs sed -i "s@/bin/sed@$(type -p sed)@g"
      '';

    };

    gpgme = {
    buildInputs = [ pkgs.gpgme.out  pkgs.gpgme.dev];
    };

}
