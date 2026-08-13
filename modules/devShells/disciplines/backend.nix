_: {
  perSystem =
    {
      config,
      pkgs,
      self',
      ...
    }:
    {
      devShells.backend = pkgs.mkShell {
        # Ensure all consumers of this devShell get git-hooks
        inputsFrom = [
          self'.devShells.git-hooks
          self'.devShells.nodejs
          self'.devShells.csharp
        ];
        packages = [
        ];

        env = {
          OTEL_EXPORTER_OTLP_PROTOCOL = "http/protobuf";
          OTEL_EXPORTER_OTLP_TRACES_ENDPOINT = "http://${
            config.process-compose."default".services.tempo."lgtp:tempo".extraConfig.distributor.receivers.otlp.protocols.http.endpoint
          }/v1/traces";
          OTEL_EXPORTER_OTLP_LOGS_ENDPOINT = "http://${
            config.process-compose."default".services.loki."lgtp:loki".httpAddress
          }:${toString config.process-compose."default".services.loki."lgtp:loki".httpPort}/otlp/v1/logs";
          OTEL_EXPORTER_OTLP_METRICS_ENDPOINT = "http://${
            config.process-compose."default".services.prometheus."lgtp:prometheus".listenAddress
          }:${
            toString config.process-compose."default".services.prometheus."lgtp:prometheus".port
          }/api/v1/otlp/v1/metrics";
        };
      };
    };
}
