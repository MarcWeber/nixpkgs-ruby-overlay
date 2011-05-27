fetchurl: platform: name:
let packages = {
      # REGION GEM: { name="nixpkgs-ruby-overlay-gem-plugin"; type="git"; url="git://gitorious.org/nixpkgs-ruby-overlay/nixpkgs-ruby-overlay-gem-plugin.git"; }
        "nixpkgs-ruby-overlay-gem-plugin"."0.2" = {
          # spec.date: 2011-03-30 00:00:00 +0200
          name = "nixpgks-ruby-overlay-gem-plugin";
          version = "0.2";
          bump = "1";
          platform = "ruby";
          developmentDependencies = [  ];
          runtimeDependencies = [  ];
          dependencies =        [  ];
          src = (fetchurl { url = "http://mawercer.de/~nix/repos/nixpkgs-ruby-overlay-gem-plugin-2.0-git-2366f.gem"; sha256 = "661d11e44d70fa6421a49813c603f72d38f5625b44ec16c0f1e7c462186876b8"; });
          meta = {
            homepage = "http://gitorious.org/nixpkgs-ruby-overlay/nixpkgs-ruby-overlay-gem-plugin";
            license = []; # one of ?
            description = "Adds 'gem nixpkgsoverlay' command that dumps all gems into format readable by nix-pkgs-ruby-overlay";
          };
        };
      # END

      # linecache and ruby-debug only compile with ruby19 in the most recent version
      # REGION GEM: { name="linecache"; type="git"; url="git://github.com/mark-moseley/linecache.git"; groups="rubydebug"; }
        "linecache19"."0.5.12" = {
          # spec.date: 2011-04-02 00:00:00 +0200
          name = "linecache19";
          version = "0.5.12";
          bump = "0.6";
          platform = "ruby";
          developmentDependencies = [  ];
          runtimeDependencies = [ ["ruby_core_source"  [[">=" "0.1.4"]]] ];
          dependencies =        [ ["ruby_core_source"  [[">=" "0.1.4"]]] ];
          src = (fetchurl { url = "http://mawercer.de/~nix/repos/linecache-0.5.12-git-8fcb8.gem"; sha256 = "eecfafb258102428b735dff6e2294e1c6c6d894e6add09aaa072a9b7ac5a0c98"; });
          meta = {
            homepage = "http://rubyforge.org/projects/ruby-debug19";
            license = []; # one of ?
            description = "Linecache is a module for reading and caching lines example in a debugger where the same lines are shown many times. ";
          };
          /* full description:
              Linecache is a module for reading and caching lines. This may be useful for
          example in a debugger where the same lines are shown many times.
          */
        };
      # END
      # REGION GEM: { name="ruby-debug"; type="git"; url="git://github.com/mark-moseley/ruby-debug.git"; groups="rubydebug"; }
        "ruby-debug-base19"."0.12.0" = {
          # spec.date: 2009-09-08 00:00:00 +0200
          name = "ruby-debug-base19";
          version = "0.12.0";
          bump = "0.13";
          platform = "ruby";
          developmentDependencies = [  ];
          runtimeDependencies = [ ["columnize"  [[">=" "0.3.1"]]] ["ruby_core_source"  [[">=" "0.1.4"]]] ["linecache19"  [[">=" "0.5.11"]]] ];
          dependencies =        [ ["columnize"  [[">=" "0.3.1"]]] ["ruby_core_source"  [[">=" "0.1.4"]]] ["linecache19"  [[">=" "0.5.11"]]] ];
          src = (fetchurl { url = "http://mawercer.de/~nix/repos/ruby-debug-0.12.0-git-58232.gem"; sha256 = "1679c110a728df77d4227cbc6189e4dcb89e3dbe9f728140ef2b5e091638c83b"; });
          meta = {
            homepage = "http://rubyforge.org/projects/ruby-debug19/";
            license = []; # one of ?
            description = "ruby-debug is a fast implementation of the standard Ruby debugger debug It is implemented by utilizing a new Ruby C API h"; # cut to 120 chars
          };
          /* full description:
              ruby-debug is a fast implementation of the standard Ruby debugger debug.rb.
          It is implemented by utilizing a new Ruby C API hook. The core component
          provides support that front-ends can build on. It provides breakpoint
          handling, bindings for stack frames among other things.
          */
        };
      # END
    };
in if builtins.hasAttr name packages then builtins.getAttr name packages else {}
