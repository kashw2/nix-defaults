{ inputs, config, ... }:
{
  flake.processComposeModules.database =
    { config, pkgs, ... }:
    {
      services.postgres."database:postgresql" = {
        enable = true;
        superuser = "postgres";
        settings = {
          logging_collector = true;
          log_directory = "log";
          log_filename = "postgresql.log";
          log_rotation_age = 0;
          log_rotation_size = 0;
        };
      };
      services.redis."database:redis" = {
        enable = true;
        extraConfig = ''
          logfile redis.log
        '';
      };
      settings.processes."database:postgresql-test" =
        with config.services.postgres."database:postgresql"; {
          command = pkgs.writeShellApplication {
            name = "postgresql-test";
            runtimeInputs = [ package ];
            text = ''
              echo 'SELECT version();' | psql -U ${superuser} -h ${listen_addresses} -p ${toString port} postgres
            '';
          };
          depends_on."database:postgresql".condition = "process_healthy";
        };
      settings.processes."database:redis-test" = with config.services.redis."database:redis"; {
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
    process-compose.database.imports = [
      inputs.services-flake.processComposeModules.default
      config.flake.processComposeModules.database
      ./_test.nix
    ];
  };
}
