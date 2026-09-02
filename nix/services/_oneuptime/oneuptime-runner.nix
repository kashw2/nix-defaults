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
      description = "The OneUptime runner package to run.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3876;
      description = "Port the runner's HTTP server listens on.";
    };

    oneuptimeUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:3002";
      description = "URL the runner reaches the OneUptime app on.";
    };

    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Extra environment variables, merged last.";
    };
  };

  config.outputs.settings.processes."${name}" = {
    environment =
      config.package.passthru.runtimeEnv
      // {
        PORT = toString config.port;
        ONEUPTIME_URL = config.oneuptimeUrl;
        ONEUPTIME_RUNNER_KEY = "oneuptime-runner";
        ONEUPTIME_RUNNER_NAME = name;
        ONEUPTIME_RUNNER_ENABLE_CODE_FIXES = "false";
      }
      // config.extraEnvironment;

    command = pkgs.writeShellApplication {
      name = "oneuptime-runner";
      runtimeInputs = [
        pkgs.nodejs_26
        pkgs.git
      ];
      text = ''
        cd ${config.package}/app
        exec node --no-node-snapshot --require ts-node/register Index.ts
      '';
    };

    readiness_probe = {
      http_get = {
        host = "127.0.0.1";
        inherit (config) port;
        path = "/status/ready";
      };
      initial_delay_seconds = 5;
      period_seconds = 5;
      timeout_seconds = 5;
      failure_threshold = 30;
    };

    availability = {
      restart = "on_failure";
      max_restarts = 3;
    };
  };
}
