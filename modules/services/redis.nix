{ inputs, config, ... }:
{
  flake.processComposeModules.redis =
    { config, pkgs, ... }:
    {
      services.redis."database:redis" = {
        enable = true;
        extraConfig = ''
          logfile redis.log
        '';
      };
      settings.processes.redis-test = with config.services.redis."database:redis"; {
        command = pkgs.writeShellApplication {
          name = "redis-test";
          runtimeInputs = [ package ];
          text = ''
            redis-cli -p ${toString port} ping
          '';
        };
        depends_on."database:redis".condition = "process_healthy";
      };
    };

  perSystem = _: {
    process-compose.redis.imports = [
      inputs.services-flake.processComposeModules.default
      config.flake.processComposeModules.redis
      ./_test.nix
    ];
  };
}
