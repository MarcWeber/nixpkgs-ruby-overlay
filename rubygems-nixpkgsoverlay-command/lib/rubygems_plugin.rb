#  usage:
#
#  install ruby-1.9 (or use a env)
#  add plugin to load path:
#  export RUBYLIB=NIXPKGS_RUBY_OVERLAY/rubygems-nixpkgsoverlay-command/lib${RUBYLIB:+:}${RUBYLIB}
#
#  run gem like this:
#  gem nixpkgsoverlay NIXPKGS_RUBY_OVERLAY/pkgs/ruby-packages.nix

require 'rubygems/command_manager'

Gem::CommandManager.instance.register_command :nixpkgsoverlay
