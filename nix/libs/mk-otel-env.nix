{
  flake.lib.mkOtelEnv =
    lib: services:
    if (services.alloy."telemetry:alloy".enable or false) then
      {
        OTEL_EXPORTER_OTLP_PROTOCOL = "http/protobuf";
        OTEL_EXPORTER_OTLP_TRACES_ENDPOINT = "http://${
          services.alloy."telemetry:alloy".listenAddress
        }:4328/v1/traces";
        OTEL_EXPORTER_OTLP_LOGS_ENDPOINT = "http://${
          services.alloy."telemetry:alloy".listenAddress
        }:4328/v1/logs";
        OTEL_EXPORTER_OTLP_METRICS_ENDPOINT = "http://${
          services.alloy."telemetry:alloy".listenAddress
        }:4328/v1/metrics";
      }
    else if (services.openobserve."openobserve".enable or false) then
      {
        OTEL_EXPORTER_OTLP_PROTOCOL = "http/protobuf";
        OTEL_EXPORTER_OTLP_HEADERS = "Authorization=Basic YWRtaW5Ac2VydmljZXMtZmxha2UuY29tOkFkbWluMSFA";
        OTEL_EXPORTER_OTLP_TRACES_ENDPOINT = "http://${services.openobserve."openobserve".httpAddress}:${
          toString services.openobserve."openobserve".httpPort
        }/api/default/v1/traces";
        OTEL_EXPORTER_OTLP_LOGS_ENDPOINT = "http://${services.openobserve."openobserve".httpAddress}:${
          toString services.openobserve."openobserve".httpPort
        }/api/default/v1/logs";
        OTEL_EXPORTER_OTLP_METRICS_ENDPOINT = "http://${services.openobserve."openobserve".httpAddress}:${
          toString services.openobserve."openobserve".httpPort
        }/api/default/v1/metrics";
      }
    else if
      (services.oneuptime-app."oneuptime:app".enable or false)
      && (services.oneuptime-app."oneuptime:app".telemetryIngestionKey or null) != null
    then
      (otlp: {
        OTEL_EXPORTER_OTLP_PROTOCOL = "http/protobuf";
        OTEL_EXPORTER_OTLP_HEADERS = "x-oneuptime-token=${
          services.oneuptime-app."oneuptime:app".telemetryIngestionKey
        }";
        OTEL_EXPORTER_OTLP_TRACES_ENDPOINT = "${otlp}/traces";
        OTEL_EXPORTER_OTLP_LOGS_ENDPOINT = "${otlp}/logs";
        OTEL_EXPORTER_OTLP_METRICS_ENDPOINT = "${otlp}/metrics";
      })
        "http://${services.oneuptime-app."oneuptime:app".listenAddress}:${
          toString services.oneuptime-app."oneuptime:app".port
        }/otlp/v1"
    else
      lib.optionalAttrs
        (
          (services.tempo."lgtp:tempo".enable or false)
          || (services.loki."lgtp:loki".enable or false)
          || (services.prometheus."lgtp:prometheus".enable or false)
        )
        (
          {
            OTEL_EXPORTER_OTLP_PROTOCOL = "http/protobuf";
            OTEL_EXPORTER_OTLP_HEADERS = "X-Scope-OrgID=1";
          }
          // lib.optionalAttrs (services.tempo."lgtp:tempo".enable or false) {
            OTEL_EXPORTER_OTLP_TRACES_ENDPOINT = "http://${
              services.tempo."lgtp:tempo".extraConfig.distributor.receivers.otlp.protocols.http.endpoint
            }/v1/traces";
          }
          // lib.optionalAttrs (services.loki."lgtp:loki".enable or false) {
            OTEL_EXPORTER_OTLP_LOGS_ENDPOINT = "http://${services.loki."lgtp:loki".httpAddress}:${
              toString services.loki."lgtp:loki".httpPort
            }/otlp/v1/logs";
          }
          // lib.optionalAttrs (services.prometheus."lgtp:prometheus".enable or false) {
            OTEL_EXPORTER_OTLP_METRICS_ENDPOINT = "http://${
              services.prometheus."lgtp:prometheus".listenAddress
            }:${toString services.prometheus."lgtp:prometheus".port}/api/v1/otlp/v1/metrics";
          }
        );
}
