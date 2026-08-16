{ inputs, config, ... }:
{
  flake.processComposeModules.lgtp =
    { config, ... }:
    {
      services.loki."lgtp:loki".enable = true;
      services.prometheus."lgtp:prometheus" = {
        enable = true;
        extraFlags = [
          "--web.enable-otlp-receiver"
          "--web.enable-remote-write-receiver"
        ];
      };
      services.tempo."lgtp:tempo" =
        { config, ... }:
        {
          enable = true;
          extraConfig = {
            # Tempo and pyroscope both default gRPC to 9095. Keep pyroscope on the
            # default (its internal metastore client hardcodes 9095) and move tempo.
            server.grpc_listen_port = 9097;
            distributor.receivers.otlp.protocols.http.endpoint = "${config.httpAddress}:4318";
            # TODO: remove once merged: https://github.com/juspay/services-flake/pull/716
            live_store = {
              shutdown_marker_dir = "${config.dataDir}/live-store/shutdown-marker";
              wal.path = "${config.dataDir}/live-store/traces";
            };
          };
        };
      services.grafana."lgtp:grafana" = {
        enable = true;
        # Provision the rest of the lgtp stack as grafana data sources. URLs are
        # derived from each service's own listen address/port so they stay in sync.
        datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            access = "proxy";
            uid = "prometheus";
            url = "http://${config.services.prometheus."lgtp:prometheus".listenAddress}:${
              toString config.services.prometheus."lgtp:prometheus".port
            }";
            isDefault = true;
          }
          {
            name = "Loki";
            type = "loki";
            access = "proxy";
            uid = "loki";
            url = "http://${config.services.loki."lgtp:loki".httpAddress}:${
              toString config.services.loki."lgtp:loki".httpPort
            }";
            jsonData.httpHeaderName1 = "X-Scope-OrgID";
            secureJsonData.httpHeaderValue1 = "1";
          }
          {
            name = "Tempo";
            type = "tempo";
            access = "proxy";
            uid = "tempo";
            url = "http://${config.services.tempo."lgtp:tempo".httpAddress}:${
              toString config.services.tempo."lgtp:tempo".httpPort
            }";
            jsonData.serviceMap.datasourceUid = "prometheus";
          }
        ];
      };
    };

  perSystem = _: {
    process-compose.lgtp.imports = [
      inputs.services-flake.processComposeModules.default
      config.flake.processComposeModules.lgtp
    ];
  };
}
