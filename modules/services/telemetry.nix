{ inputs, config, ... }:
{
  flake.processComposeModules.telemetry =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      imports = [
        (inputs.services-flake.lib.multiService ./_alloy/alloy.nix)
      ];

      services.alloy."telemetry:alloy" = {
        enable = true;
        extraFlags = [
          "--disable-reporting"
          "--stability.level=experimental"
        ];
        configFile = pkgs.writeText "config.alloy" ''
          livedebugging {
            enabled = true
          }

          otelcol.receiver.otlp "default" {
            grpc { endpoint = "${config.services.alloy."telemetry:alloy".listenAddress}:4327" }
            http { endpoint = "${config.services.alloy."telemetry:alloy".listenAddress}:4328" }
            output {
              metrics = [otelcol.processor.batch.default.input]
              logs    = [otelcol.processor.batch.default.input]
              traces  = [otelcol.processor.batch.default.input]
            }
          }

          otelcol.processor.batch "default" {
            output {
              metrics = [otelcol.processor.attributes.default.input]
              logs    = [otelcol.processor.attributes.default.input]
              traces  = [otelcol.processor.attributes.default.input]
            }
          }

          otelcol.processor.attributes "default" {
            action {
              key    = "deployment.environment"
              value  = "dev"
              action = "insert"
            }
            output {
              metrics = [${
                lib.concatStringsSep ", " (
                  lib.optional (config.services.prometheus."lgtp:prometheus".enable or false
                  ) "otelcol.exporter.otlphttp.metrics.input"
                  ++ lib.optional (config.services.openobserve."openobserve".enable or false
                  ) "otelcol.exporter.otlphttp.openobserve.input"
                )
              }]
              logs    = [${
                lib.concatStringsSep ", " (
                  lib.optional (config.services.loki."lgtp:loki".enable or false
                  ) "otelcol.exporter.otlphttp.logs.input"
                  ++ lib.optional (config.services.openobserve."openobserve".enable or false
                  ) "otelcol.exporter.otlphttp.openobserve.input"
                )
              }]
              traces  = [${
                lib.concatStringsSep ", " (
                  lib.optional (config.services.tempo."lgtp:tempo".enable or false
                  ) "otelcol.exporter.otlphttp.traces.input"
                  ++ lib.optional (config.services.openobserve."openobserve".enable or false
                  ) "otelcol.exporter.otlphttp.openobserve.input"
                )
              }]
            }
          }
          ${
            lib.optionalString (config.services.tempo."lgtp:tempo".enable or false) ''

              otelcol.exporter.otlphttp "traces" {
                client {
                  endpoint = "http://${
                    config.services.tempo."lgtp:tempo".extraConfig.distributor.receivers.otlp.protocols.http.endpoint
                  }"
                  tls { insecure = true }
                }
              }
            ''
          }${
            lib.optionalString (config.services.loki."lgtp:loki".enable or false) ''

              otelcol.exporter.otlphttp "logs" {
                client {
                  endpoint = "http://${config.services.loki."lgtp:loki".httpAddress}:${
                    toString config.services.loki."lgtp:loki".httpPort
                  }/otlp"
                  headers  = { "X-Scope-OrgID" = "1" }
                  tls { insecure = true }
                }
              }
            ''
          }${
            lib.optionalString (config.services.prometheus."lgtp:prometheus".enable or false) ''

              otelcol.exporter.otlphttp "metrics" {
                client {
                  endpoint = "http://${config.services.prometheus."lgtp:prometheus".listenAddress}:${
                    toString config.services.prometheus."lgtp:prometheus".port
                  }/api/v1/otlp"
                  tls { insecure = true }
                }
              }

              prometheus.scrape "alloy_self" {
                targets    = [{ __address__ = "${config.services.alloy."telemetry:alloy".listenAddress}:${
                  toString config.services.alloy."telemetry:alloy".port
                }" }]
                forward_to = [prometheus.remote_write.default.receiver${
                  lib.optionalString (config.services.openobserve."openobserve".enable or false
                  ) ", otelcol.receiver.prometheus.openobserve_self.receiver"
                }]
              }

              prometheus.remote_write "default" {
                endpoint { url = "http://${config.services.prometheus."lgtp:prometheus".listenAddress}:${
                  toString config.services.prometheus."lgtp:prometheus".port
                }/api/v1/write" }
              }
            ''
          }${
            lib.optionalString (config.services.loki."lgtp:loki".enable or false) ''

              logging {
                level    = "info"
                format   = "logfmt"
                write_to = [loki.write.internal.receiver${
                  lib.optionalString (config.services.openobserve."openobserve".enable or false
                  ) ", otelcol.receiver.loki.openobserve_self.receiver"
                }]
              }

              loki.write "internal" {
                endpoint {
                  url       = "http://${config.services.loki."lgtp:loki".httpAddress}:${
                    toString config.services.loki."lgtp:loki".httpPort
                  }/loki/api/v1/push"
                  tenant_id = "1"
                }
              }
            ''
          }${
            lib.optionalString (config.services.openobserve."openobserve".enable or false) ''

              otelcol.auth.basic "openobserve" {
                username = "admin@services-flake.com"
                password = "Admin1!@"
              }

              otelcol.exporter.otlphttp "openobserve" {
                client {
                  endpoint = "http://${config.services.openobserve."openobserve".httpAddress}:${
                    toString config.services.openobserve."openobserve".httpPort
                  }/api/default"
                  auth = otelcol.auth.basic.openobserve.handler
                  tls { insecure = true }
                }
              }

              otelcol.receiver.prometheus "openobserve_self" {
                output { metrics = [otelcol.exporter.otlphttp.openobserve.input] }
              }

              otelcol.receiver.loki "openobserve_self" {
                output { logs = [otelcol.exporter.otlphttp.openobserve.input] }
              }
            ''
          }${
            lib.optionalString (config.services.postgres."database:postgresql".enable or false) ''

              prometheus.exporter.postgres "database" {
                data_source_names = ["postgresql://${config.services.postgres."database:postgresql".superuser}@${
                  config.services.postgres."database:postgresql".listen_addresses
                }:${toString config.services.postgres."database:postgresql".port}/postgres?sslmode=disable"]
              }

              prometheus.scrape "database_postgresql" {
                targets    = prometheus.exporter.postgres.database.targets
                forward_to = [${
                  lib.concatStringsSep ", " (
                    lib.optional (config.services.prometheus."lgtp:prometheus".enable or false
                    ) "prometheus.remote_write.default.receiver"
                    ++ lib.optional (config.services.openobserve."openobserve".enable or false
                    ) "otelcol.receiver.prometheus.openobserve_self.receiver"
                  )
                }]
              }

              local.file_match "database_postgresql" {
                path_targets = [{ __path__ = "${
                  config.services.postgres."database:postgresql".dataDir
                }/log/*.log" }]
              }

              loki.source.file "database_postgresql" {
                targets    = local.file_match.database_postgresql.targets
                forward_to = [${
                  lib.concatStringsSep ", " (
                    lib.optional (config.services.loki."lgtp:loki".enable or false) "loki.write.internal.receiver"
                    ++ lib.optional (config.services.openobserve."openobserve".enable or false
                    ) "otelcol.receiver.loki.openobserve_self.receiver"
                  )
                }]
              }
            ''
          }
        '';
      };

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
        datasources = [
          {
            name = "Pyroscope";
            type = "grafana-pyroscope-datasource";
            access = "proxy";
            uid = "pyroscope";
            url = "http://${config.services.pyroscope."telemetry:pyroscope".httpAddress}:${
              toString config.services.pyroscope."telemetry:pyroscope".httpPort
            }";
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
