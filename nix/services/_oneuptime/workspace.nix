{
  defaultPort,
  environment,
  runtimeInputs ? _: [ ],
}:
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
      description = "Package to run.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = defaultPort;
      description = "Port the HTTP server listens on.";
    };

    oneuptimeUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:3002";
      description = "URL the app is reached on.";
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
      }
      // environment name
      // config.extraEnvironment;

    command = pkgs.writeShellApplication {
      name = config.package.pname;
      runtimeInputs = [ pkgs.nodejs_26 ] ++ runtimeInputs pkgs;
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
