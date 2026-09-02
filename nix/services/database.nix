{ inputs, config, ... }:
{
  flake.processComposeModules.database =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      config = {
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
        services.clickhouse."database:clickhouse" = {
          enable = true;
          extraConfig = with config.services.clickhouse."database:clickhouse"; {
            http_port = 8123;
            user_directories.users_xml.path = pkgs.runCommand "clickhouse-users.xml" { } ''
              substitute ${package}/etc/clickhouse-server/users.xml "$out" \
                --replace-fail '<password></password>' '<password>password</password>'
            '';
          };
        };
        settings.processes = lib.mkMerge [
          {
            "database:postgresql-test" = with config.services.postgres."database:postgresql"; {
              command = pkgs.writeShellApplication {
                name = "postgresql-test";
                runtimeInputs = [ package ];
                text = ''
                  echo 'SELECT version();' | psql -U ${superuser} -h ${listen_addresses} -p ${toString port} postgres
                '';
              };
              depends_on."database:postgresql".condition = "process_healthy";
            };
            "database:redis-test" = with config.services.redis."database:redis"; {
              command = pkgs.writeShellApplication {
                name = "redis-test";
                runtimeInputs = [ package ];
                text = ''
                  redis-cli -p ${toString port} ping
                '';
              };
              depends_on."database:redis".condition = "process_healthy";
            };
          }
          (lib.mkIf config.services.clickhouse."database:clickhouse".enable (
            lib.genAttrs [ "database:clickhouse" "database:clickhouse-init" ] (_: {
              environment = {
                TZ = "UTC";
                CLICKHOUSE_PASSWORD = "password";
              };
            })
            // {
              "database:clickhouse-test" = with config.services.clickhouse."database:clickhouse"; {
                environment.TZ = "UTC";
                command = pkgs.writeShellApplication {
                  name = "clickhouse-test";
                  runtimeInputs = [
                    package
                    pkgs.curl
                  ];
                  text = ''
                    clickhouse-client --port ${toString port} --password password --query 'SELECT 1'
                    test "$(curl -fsS --user default:password \
                      'http://127.0.0.1:${toString extraConfig.http_port}/' --data-binary 'SELECT 1')" = 1
                  '';
                };
                depends_on."database:clickhouse".condition = "process_healthy";
              };
            }
          ))
        ];
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
