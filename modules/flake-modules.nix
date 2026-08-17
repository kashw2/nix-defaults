{ lib, ... }:
let
  processComposeModules = {
    options.flake.processComposeModules = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.deferredModule;
      default = { };
      description = "process-compose/services-flake modules exported by this flake, for use by other flakes.";
    };
  };
in
{
  imports = [ processComposeModules ];

  options.flake.flakeModules = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.deferredModule;
    default = { };
    description = "flake-parts modules exported by this flake, for use by other flakes.";
  };

  config.flake.flakeModules.processComposeModules = processComposeModules;
}
