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
          src = (fetchurl { url = "http://mawercer.de/~nix/repos/nixpkgs-ruby-overlay-gem-plugin-2.0-git-2366f.gem"; sha256 = "861088995409971f82df97ce62b1cb5b20996da2b96f50cf05982448ee24dcab"; });

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
          # spec.date: 2011-04-02 00:00:00 UTC
          name = "linecache19";
          version = "0.5.12";
          bump = "0.6";
          platform = "ruby";
          developmentDependencies = [  ];
          runtimeDependencies = [ ["ruby_core_source"  [[">=" "0.1.4"]]] ];
          dependencies =        [ ["ruby_core_source"  [[">=" "0.1.4"]]] ];
          src = (fetchurl { url = "http://mawercer.de/~nix/repos/linecache-0.5.12-git-869c6.gem"; sha256 = "4516e02033c356566dc127f964ed947da4686509d9331a8908a8eaf0a6362459"; });
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
          # spec.date: 2009-09-08 00:00:00 UTC
          name = "ruby-debug-base19";
          version = "0.12.0";
          bump = "0.13";
          platform = "ruby";
          developmentDependencies = [  ];
          runtimeDependencies = [ ["columnize"  [[">=" "0.3.1"]]] ["ruby_core_source"  [[">=" "0.1.4"]]] ["linecache19"  [[">=" "0.5.11"]]] ];
          dependencies =        [ ["columnize"  [[">=" "0.3.1"]]] ["ruby_core_source"  [[">=" "0.1.4"]]] ["linecache19"  [[">=" "0.5.11"]]] ];
          src = (fetchurl { url = "http://mawercer.de/~nix/repos/ruby-debug-0.12.0-git-01723.gem"; sha256 = "32bafc6e7d218ac110d77e5968b69e37e3e2c338d8fd33f3557e9e386bfcc531"; });
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

      # see pkgs/defaults.nix
      "HTTP-Live-Video-Stream-Segmenter-and-Distributor"."0.0.0" = {
        # spec.date: 2009-09-08 00:00:00 UTC
        name = "HTTP-Live-Video-Stream-Segmenter-and-Distributor";
        version = "0.0.0";
        bump = "0.0";
        platform = "ruby";
        developmentDependencies = [  ];
        runtimeDependencies = [];
        dependencies =        [];
        src = {
          # REGION AUTO UPDATE: { name="HTTP-Live-Video-Stream-Segmenter-and-Distributor"; type="git"; url="git@github.com:carsonmcdonald/HTTP-Live-Video-Stream-Segmenter-and-Distributor.git"; groups=""; }
          src = (fetchurl { url = "http://mawercer.de/~nix/repos/HTTP-Live-Video-Stream-Segmenter-and-Distributor-git-7540a.tar.bz2"; sha256 = "279a1857e09319a95f0f8cccd16fc83ffa66909bbd63179cabcd810c484fd0cb"; });
          name = "HTTP-Live-Video-Stream-Segmenter-and-Distributor-git-7540a";
          # END
        }.src;
        meta = {
        };
      };
    };
in if builtins.hasAttr name packages then builtins.getAttr name packages else {}
