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
