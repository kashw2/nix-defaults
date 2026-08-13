{ inputs, config, ... }:
{
  flake.processComposeModules.telemetry =
    { lib, config, ... }:
    {
      services.pyroscope."telemetry:pyroscope".enable = true;
      # TODO: remove once merged: https://github.com/juspay/services-flake/pull/715
      settings.processes."telemetry:pyroscope".readiness_probe = lib.mkForce {
        http_get = {
          host = "127.0.0.1";
          scheme = "http";
          port = 4040;
          path = "/ready";
        };
        initial_delay_seconds = 30;
        period_seconds = 10;
        timeout_seconds = 2;
        success_threshold = 1;
        failure_threshold = 30;
      };
      services.grafana."lgtp:grafana" = {
        enable = true;
        # Provision the rest of the lgtp stack as grafana data sources. URLs are
        # derived from each service's own listen address/port so they stay in sync.
        datasources =
          let
            dsUrl = address: port: "http://${address}:${toString port}";
          in
          [
            {
              name = "Pyroscope";
              type = "grafana-pyroscope-datasource";
              access = "proxy";
              uid = "pyroscope";
              url =
                dsUrl config.services.pyroscope."telemetry:pyroscope".httpAddress
                  config.services.pyroscope."telemetry:pyroscope".httpPort;
            }
          ];
      };
    };

  perSystem = _: {
    process-compose.telemetry.imports = [
      inputs.services-flake.processComposeModules.default
      config.flake.processComposeModules.telemetry
    ];
  };
}
