fetchurl: platform: name:
let packages = {
      # REGION GEM: { name="nixpkgs-ruby-overlay-gem-plugin"; type="git"; url="git://gitorious.org/nixpkgs-ruby-overlay/nixpkgs-ruby-overlay-gem-plugin.git"; }
        "nixpgks-ruby-overlay-gem-plugin"."0.2" = {
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
    };
in if builtins.hasAttr name packages then builtins.getAttr name packages else {}
