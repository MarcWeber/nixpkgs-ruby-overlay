fetchurl: platform: name:
  if name == "nixpkgs-ruby-overlay-gem-plugin" then {
    "0.2" = {
      name = "nixpgks-ruby-overlay-gem-plugin";
      version = "0.2";
      bump = "1";
      platform = "ruby";
      developmentDependencies = [  ];
      runtimeDependencies = [  ];
      dependencies =        [  ];
      src = fetchurl {
        url = http://mawercer.de/~marc/nixpgks-ruby-overlay-gem-plugin-0.2.gem;
        sha256 = "0mj5ik0dkzvyv1l3am5i4vaxx4jwnv0rb2yp2dcjq8jvscaav02a";
      };
      meta = {
        homepage = "http://gitorious.org/nixpkgs-ruby-overlay/nixpkgs-ruby-overlay-gem-plugin";
        license = []; # one of ?
        description = "Adds 'gem nixpkgsoverlay' command that dumps all gems into format readable by nix-pkgs-ruby-overlay";
      };
    };
  }
  else {}
