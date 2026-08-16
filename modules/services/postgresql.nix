{ inputs, config, ... }:
{
  flake.processComposeModules.postgresql =
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
      settings.processes.postgresql-test = with config.services.postgres."database:postgresql"; {
        command = pkgs.writeShellApplication {
          name = "postgresql-test";
          runtimeInputs = [ package ];
          text = ''
            echo 'SELECT version();' | psql -U ${superuser} -h ${listen_addresses} -p ${toString port} postgres
          '';
        };
        depends_on."database:postgresql".condition = "process_healthy";

      };
    };

  perSystem = _: {
    process-compose.postgresql.imports = [
      inputs.services-flake.processComposeModules.default
      config.flake.processComposeModules.postgresql
      ./_test.nix
    ];
  };
}
