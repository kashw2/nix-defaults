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
                  ++ lib.optional (
                    (config.services.prometheus."lgtp:prometheus".enable or false)
                    || (config.services.openobserve."openobserve".enable or false)
                  ) "otelcol.connector.servicegraph.default.input"
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
                }", discipline = "${lib.head (lib.splitString ":" "telemetry:alloy")}", service = "${lib.last (lib.splitString ":" "telemetry:alloy")}" }]
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
                forward_to = [prometheus.relabel.database_postgresql.receiver]
              }

              prometheus.relabel "database_postgresql" {
                forward_to = [${
                  lib.concatStringsSep ", " (
                    lib.optional (config.services.prometheus."lgtp:prometheus".enable or false
                    ) "prometheus.remote_write.default.receiver"
                    ++ lib.optional (config.services.openobserve."openobserve".enable or false
                    ) "otelcol.receiver.prometheus.openobserve_self.receiver"
                  )
                }]
                rule {
                  target_label = "discipline"
                  replacement  = "${lib.head (lib.splitString ":" "database:postgresql")}"
                }
                rule {
                  target_label = "service"
                  replacement  = "${lib.last (lib.splitString ":" "database:postgresql")}"
                }
              }

              local.file_match "database_postgresql" {
                path_targets = [{ __path__ = "${
                  config.services.postgres."database:postgresql".dataDir
                }/log/*.log" }]
              }

              loki.source.file "database_postgresql" {
                targets    = local.file_match.database_postgresql.targets
                forward_to = [loki.process.database_postgresql.receiver]
              }

              loki.process "database_postgresql" {
                forward_to = [${
                  lib.concatStringsSep ", " (
                    lib.optional (config.services.loki."lgtp:loki".enable or false) "loki.write.internal.receiver"
                    ++ lib.optional (config.services.openobserve."openobserve".enable or false
                    ) "otelcol.receiver.loki.openobserve_self.receiver"
                  )
                }]
                stage.static_labels {
                  values = {
                    discipline = "${lib.head (lib.splitString ":" "database:postgresql")}",
                    service    = "${lib.last (lib.splitString ":" "database:postgresql")}",
                  }
                }
              }
            ''
          }${
            lib.optionalString (config.services.redis."database:redis".enable or false) ''

              prometheus.exporter.redis "database" {
                redis_addr = "127.0.0.1:${toString config.services.redis."database:redis".port}"
              }

              prometheus.scrape "database_redis" {
                targets    = prometheus.exporter.redis.database.targets
                forward_to = [prometheus.relabel.database_redis.receiver]
              }

              prometheus.relabel "database_redis" {
                forward_to = [${
                  lib.concatStringsSep ", " (
                    lib.optional (config.services.prometheus."lgtp:prometheus".enable or false
                    ) "prometheus.remote_write.default.receiver"
                    ++ lib.optional (config.services.openobserve."openobserve".enable or false
                    ) "otelcol.receiver.prometheus.openobserve_self.receiver"
                  )
                }]
                rule {
                  target_label = "discipline"
                  replacement  = "${lib.head (lib.splitString ":" "database:redis")}"
                }
                rule {
                  target_label = "service"
                  replacement  = "${lib.last (lib.splitString ":" "database:redis")}"
                }
              }

              local.file_match "database_redis" {
                path_targets = [{ __path__ = "${config.services.redis."database:redis".dataDir}/redis.log" }]
              }

              loki.source.file "database_redis" {
                targets    = local.file_match.database_redis.targets
                forward_to = [loki.process.database_redis.receiver]
              }

              loki.process "database_redis" {
                forward_to = [${
                  lib.concatStringsSep ", " (
                    lib.optional (config.services.loki."lgtp:loki".enable or false) "loki.write.internal.receiver"
                    ++ lib.optional (config.services.openobserve."openobserve".enable or false
                    ) "otelcol.receiver.loki.openobserve_self.receiver"
                  )
                }]
                stage.static_labels {
                  values = {
                    discipline = "${lib.head (lib.splitString ":" "database:redis")}",
                    service    = "${lib.last (lib.splitString ":" "database:redis")}",
                  }
                }
              }
            ''
          }${
            lib.optionalString (config.services.seaweedfs."storage:seaweedfs".enable or false) ''

              prometheus.scrape "storage_seaweedfs" {
                targets    = [{ __address__ = "${config.services.seaweedfs."storage:seaweedfs".host}:9494" }]
                forward_to = [prometheus.relabel.storage_seaweedfs.receiver]
              }

              prometheus.relabel "storage_seaweedfs" {
                forward_to = [${
                  lib.concatStringsSep ", " (
                    lib.optional (config.services.prometheus."lgtp:prometheus".enable or false
                    ) "prometheus.remote_write.default.receiver"
                    ++ lib.optional (config.services.openobserve."openobserve".enable or false
                    ) "otelcol.receiver.prometheus.openobserve_self.receiver"
                  )
                }]
                rule {
                  target_label = "discipline"
                  replacement  = "${lib.head (lib.splitString ":" "storage:seaweedfs")}"
                }
                rule {
                  target_label = "service"
                  replacement  = "${lib.last (lib.splitString ":" "storage:seaweedfs")}"
                }
              }

              local.file_match "storage_seaweedfs" {
                path_targets = [{ __path__ = "${
                  config.services.seaweedfs."storage:seaweedfs".dataDir
                }/seaweedfs.log" }]
              }

              loki.source.file "storage_seaweedfs" {
                targets    = local.file_match.storage_seaweedfs.targets
                forward_to = [loki.process.storage_seaweedfs.receiver]
              }

              loki.process "storage_seaweedfs" {
                forward_to = [${
                  lib.concatStringsSep ", " (
                    lib.optional (config.services.loki."lgtp:loki".enable or false) "loki.write.internal.receiver"
                    ++ lib.optional (config.services.openobserve."openobserve".enable or false
                    ) "otelcol.receiver.loki.openobserve_self.receiver"
                  )
                }]
                stage.static_labels {
                  values = {
                    discipline = "${lib.head (lib.splitString ":" "storage:seaweedfs")}",
                    service    = "${lib.last (lib.splitString ":" "storage:seaweedfs")}",
                  }
                }
              }
            ''
          }${
            lib.optionalString
              (
                (config.services.prometheus."lgtp:prometheus".enable or false)
                || (config.services.openobserve."openobserve".enable or false)
              )
              ''

                prometheus.scrape "observability" {
                  targets = [${
                    lib.concatStringsSep ", " (
                      lib.optional (config.services.prometheus."lgtp:prometheus".enable or false)
                        ''{ __address__ = "${config.services.prometheus."lgtp:prometheus".listenAddress}:${
                          toString config.services.prometheus."lgtp:prometheus".port
                        }", job = "prometheus", discipline = "${lib.head (lib.splitString ":" "lgtp:prometheus")}", service = "${lib.last (lib.splitString ":" "lgtp:prometheus")}" }''
                      ++
                        lib.optional (config.services.loki."lgtp:loki".enable or false)
                          ''{ __address__ = "${config.services.loki."lgtp:loki".httpAddress}:${
                            toString config.services.loki."lgtp:loki".httpPort
                          }", job = "loki", discipline = "${lib.head (lib.splitString ":" "lgtp:loki")}", service = "${lib.last (lib.splitString ":" "lgtp:loki")}" }''
                      ++
                        lib.optional (config.services.tempo."lgtp:tempo".enable or false)
                          ''{ __address__ = "${config.services.tempo."lgtp:tempo".httpAddress}:${
                            toString config.services.tempo."lgtp:tempo".httpPort
                          }", job = "tempo", discipline = "${lib.head (lib.splitString ":" "lgtp:tempo")}", service = "${lib.last (lib.splitString ":" "lgtp:tempo")}" }''
                      ++
                        lib.optional (config.services.pyroscope."telemetry:pyroscope".enable or false)
                          ''{ __address__ = "${config.services.pyroscope."telemetry:pyroscope".httpAddress}:${
                            toString config.services.pyroscope."telemetry:pyroscope".httpPort
                          }", job = "pyroscope", discipline = "${lib.head (lib.splitString ":" "telemetry:pyroscope")}", service = "${lib.last (lib.splitString ":" "telemetry:pyroscope")}" }''
                      ++
                        lib.optional (config.services.grafana."lgtp:grafana".enable or false)
                          ''{ __address__ = "127.0.0.1:${
                            toString config.services.grafana."lgtp:grafana".http_port
                          }", job = "grafana", discipline = "${lib.head (lib.splitString ":" "lgtp:grafana")}", service = "${lib.last (lib.splitString ":" "lgtp:grafana")}" }''
                      ++
                        lib.optional (config.services.openobserve."openobserve".enable or false)
                          ''{ __address__ = "${config.services.openobserve."openobserve".httpAddress}:${
                            toString config.services.openobserve."openobserve".httpPort
                          }", job = "openobserve", discipline = "${lib.head (lib.splitString ":" "openobserve")}", service = "${lib.last (lib.splitString ":" "openobserve")}" }''
                    )
                  }]
                  forward_to = [${
                    lib.concatStringsSep ", " (
                      lib.optional (config.services.prometheus."lgtp:prometheus".enable or false
                      ) "prometheus.remote_write.default.receiver"
                      ++ lib.optional (config.services.openobserve."openobserve".enable or false
                      ) "otelcol.receiver.prometheus.openobserve_self.receiver"
                    )
                  }]
                }
              ''
          }${
            lib.optionalString
              (
                (config.services.prometheus."lgtp:prometheus".enable or false)
                || (config.services.openobserve."openobserve".enable or false)
              )
              ''

                otelcol.connector.servicegraph "default" {
                  output {
                    metrics = [${
                      lib.concatStringsSep ", " (
                        lib.optional (config.services.prometheus."lgtp:prometheus".enable or false
                        ) "otelcol.exporter.otlphttp.metrics.input"
                        ++ lib.optional (config.services.openobserve."openobserve".enable or false
                        ) "otelcol.exporter.otlphttp.openobserve.input"
                      )
                    }]
                  }
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
