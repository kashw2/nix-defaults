_: {
  perSystem =
    {
      config,
      lib,
      pkgs,
      self',
      ...
    }:
    {
      devShells.golang = pkgs.mkShell {
        # Ensure all consumers of this devShell get git-hooks
        inputsFrom = [ self'.devShells.base ];
        packages = [
          pkgs.go
        ];

        env =
          if (config.process-compose."default".services.alloy."telemetry:alloy".enable or false) then
            {
              OTEL_EXPORTER_OTLP_PROTOCOL = "http/protobuf";
              OTEL_EXPORTER_OTLP_TRACES_ENDPOINT = "http://${
                config.process-compose."default".services.alloy."telemetry:alloy".listenAddress
              }:4328/v1/traces";
              OTEL_EXPORTER_OTLP_LOGS_ENDPOINT = "http://${
                config.process-compose."default".services.alloy."telemetry:alloy".listenAddress
              }:4328/v1/logs";
              OTEL_EXPORTER_OTLP_METRICS_ENDPOINT = "http://${
                config.process-compose."default".services.alloy."telemetry:alloy".listenAddress
              }:4328/v1/metrics";
            }
          else
            lib.optionalAttrs
              (
                (config.process-compose."default".services.tempo."lgtp:tempo".enable or false)
                || (config.process-compose."default".services.loki."lgtp:loki".enable or false)
                || (config.process-compose."default".services.prometheus."lgtp:prometheus".enable or false)
              )
              (
                {
                  OTEL_EXPORTER_OTLP_PROTOCOL = "http/protobuf";
                  OTEL_EXPORTER_OTLP_HEADERS = "X-Scope-OrgID=1";
                }
                //
                  lib.optionalAttrs (config.process-compose."default".services.tempo."lgtp:tempo".enable or false)
                    {
                      OTEL_EXPORTER_OTLP_TRACES_ENDPOINT = "http://${
                        config.process-compose."default".services.tempo."lgtp:tempo".extraConfig.distributor.receivers.otlp.protocols.http.endpoint
                      }/v1/traces";
                    }
                // lib.optionalAttrs (config.process-compose."default".services.loki."lgtp:loki".enable or false) {
                  OTEL_EXPORTER_OTLP_LOGS_ENDPOINT = "http://${
                    config.process-compose."default".services.loki."lgtp:loki".httpAddress
                  }:${toString config.process-compose."default".services.loki."lgtp:loki".httpPort}/otlp/v1/logs";
                }
                //
                  lib.optionalAttrs
                    (config.process-compose."default".services.prometheus."lgtp:prometheus".enable or false)
                    {
                      OTEL_EXPORTER_OTLP_METRICS_ENDPOINT = "http://${
                        config.process-compose."default".services.prometheus."lgtp:prometheus".listenAddress
                      }:${
                        toString config.process-compose."default".services.prometheus."lgtp:prometheus".port
                      }/api/v1/otlp/v1/metrics";
                    }
              );
      };
    };
}
