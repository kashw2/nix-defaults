{
  pkgs,
  lib,
  name,
  config,
  ...
}:
{
  options = {
    package = lib.mkOption {
      type = lib.types.package;
      description = "The OneUptime app package to run.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address the app is reached on, for its readiness probe and self-referencing URLs.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3002;
      description = "Port the app's HTTP server listens on.";
    };

    admin = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      description = "Admin account provisioned at startup.";
    };

    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Extra environment variables, merged last.";
    };
  };

  config.outputs.settings.processes = {
    "${name}-migrate" = {
      environment =
        config.package.passthru.runtimeEnv
        // {
          NODE_OPTIONS = "--max-old-space-size=8096 --max-http-header-size=8388608";
        }
        // config.extraEnvironment;

      command = pkgs.writeShellApplication {
        name = "oneuptime-migrate";
        runtimeInputs = [ pkgs.nodejs_26 ];
        text = ''
          cd ${config.package}/app
          exec node --no-node-snapshot --require ts-node/register Migrate.ts
        '';
      };

      availability.restart = "exit_on_failure";
    };

    "${name}" = {
      environment =
        config.package.passthru.runtimeEnv
        // {
          PORT = toString config.port;
          NODE_OPTIONS = "--max-old-space-size=8096";
        }
        // config.extraEnvironment;

      command = pkgs.writeShellApplication {
        name = "oneuptime-app";
        runtimeInputs = [ pkgs.nodejs_26 ];
        text = ''
          cd ${config.package}/app
          exec node --no-node-snapshot --require ts-node/register Index.ts
        '';
      };

      depends_on."${name}-migrate".condition = "process_completed_successfully";

      readiness_probe = {
        http_get = {
          host = config.listenAddress;
          inherit (config) port;
          path = "/status/ready";
        };
        initial_delay_seconds = 10;
        period_seconds = 5;
        timeout_seconds = 5;
        success_threshold = 1;
        failure_threshold = 60;
      };

      availability = {
        restart = "on_failure";
        max_restarts = 3;
      };
    };
  };
}
