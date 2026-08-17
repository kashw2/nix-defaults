{ lib, ... }:
{
  options.flake.flakeModules = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.deferredModule;
    default = { };
    description = "flake-parts modules exported by this flake, for use by other flakes.";
  };

  # Re-export our own option-declaring modules so downstream flakes can opt in.
  config.flake.flakeModules.processComposeModules = ./process-compose-modules.nix;
}
