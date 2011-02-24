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
        sha256 = "1c34f3pdc4d9mzxsz2f7mib0hqbykf81p24z1wrvrdwy9bqrpf3v";
      };
      meta = {
        homepage = "http://gitorious.org/nixpkgs-ruby-overlay/nixpkgs-ruby-overlay-gem-plugin";
        license = []; # one of ?
        description = "Adds 'gem nixpkgsoverlay' command that dumps all gems into format readable by nix-pkgs-ruby-overlay";
      };
    };
  }
  else {}
