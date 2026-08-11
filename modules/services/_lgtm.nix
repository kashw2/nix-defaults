{ config, ... }:
{
  services.loki."lgtm:loki".enable = true;
  services.prometheus."lgtm:prometheus".enable = true;
  services.tempo."lgtm:tempo" = { config, ... }: {
    enable = true;
    extraConfig = {
      # Tempo and pyroscope both default gRPC to 9095. Keep pyroscope on the
      # default (its internal metastore client hardcodes 9095) and move tempo.
      server.grpc_listen_port = 9097;
      # TODO: remove once merged: https://github.com/juspay/services-flake/pull/716
      live_store = {
        shutdown_marker_dir = "${config.dataDir}/live-store/shutdown-marker";
        wal.path = "${config.dataDir}/live-store/traces";
      };
    };
  };
  services.grafana."lgtm:grafana" = {
    enable = true;
    # Provision the rest of the lgtm stack as grafana data sources. URLs are
    # derived from each service's own listen address/port so they stay in sync.
    datasources =
      let
        dsUrl = address: port: "http://${address}:${toString port}";
      in
      [
        {
          name = "Prometheus";
          type = "prometheus";
          access = "proxy";
          uid = "prometheus";
          url =
            dsUrl config.services.prometheus."lgtm:prometheus".listenAddress
              config.services.prometheus."lgtm:prometheus".port;
          isDefault = true;
        }
        {
          name = "Loki";
          type = "loki";
          access = "proxy";
          uid = "loki";
          url = dsUrl config.services.loki."lgtm:loki".httpAddress config.services.loki."lgtm:loki".httpPort;
        }
        {
          name = "Tempo";
          type = "tempo";
          access = "proxy";
          uid = "tempo";
          url =
            dsUrl config.services.tempo."lgtm:tempo".httpAddress
              config.services.tempo."lgtm:tempo".httpPort;
        }
      ];
  };
}
