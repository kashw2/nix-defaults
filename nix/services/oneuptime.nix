{
  self,
  inputs,
  config,
  ...
}:
{
  flake.processComposeModules.oneuptime =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      imports = [
        (inputs.services-flake.lib.multiService ./_oneuptime/oneuptime-app.nix)
        (inputs.services-flake.lib.multiService ./_oneuptime/oneuptime-runner.nix)
        (inputs.services-flake.lib.multiService ./_oneuptime/oneuptime-probe.nix)
      ];

      services.clickhouse."database:clickhouse".initialDatabases = [ { name = "oneuptime"; } ];

      services.clickhouse."database:clickhouse".extraConfig =
        with config.services.clickhouse."database:clickhouse"; {
          interserver_http_port = 9009;
          interserver_http_host = "localhost";
          keeper_server = {
            tcp_port = 9181;
            server_id = 1;
            log_storage_path = "${dataDir}/clickhouse/coordination/log";
            snapshot_storage_path = "${dataDir}/clickhouse/coordination/snapshots";
            coordination_settings = {
              operation_timeout_ms = 10000;
              session_timeout_ms = 30000;
              raft_logs_level = "warning";
            };
            raft_configuration.server = {
              id = 1;
              hostname = "localhost";
              port = 9234;
            };
          };
          zookeeper.node = {
            host = "localhost";
            port = 9181;
          };
          distributed_ddl = {
            path = "/clickhouse/task_queue/ddl";
            replicas_path = "/clickhouse/task_queue/replicas";
          };
          macros = {
            shard = "01";
            replica = "replica-1";
            cluster = "oneuptime";
          };
          remote_servers.oneuptime.shard = {
            internal_replication = true;
            replica = {
              host = "localhost";
              inherit port;
            };
          };
        };

      services.postgres."database:postgresql".initialDatabases = [ { name = "oneuptimedb"; } ];

      services.oneuptime-app."oneuptime:app" = with config.services.oneuptime-app."oneuptime:app"; {
        package = self.packages.${pkgs.stdenv.hostPlatform.system}.oneuptime-app;
        enable = true;
        extraEnvironment = {
          HOST = "${listenAddress}:${toString config.services.nginx."proxies:nginx".port}";
          HTTP_PROTOCOL = "http";
          NODE_ENV = "production";
          PRODUCTION = "true";
          TS_NODE_TRANSPILE_ONLY = "1";

          ONEUPTIME_SECRET = "oneuptime-secret";
          ENCRYPTION_SECRET = "oneuptime-encryption";
          REGISTER_PROBE_KEY = "oneuptime-register-probe";

          APP_PORT = toString port;
          SERVER_APP_HOSTNAME = listenAddress;

          DATABASE_HOST = config.services.postgres."database:postgresql".listen_addresses;
          DATABASE_PORT = toString config.services.postgres."database:postgresql".port;
          DATABASE_NAME = "oneuptimedb";
          DATABASE_USERNAME = config.services.postgres."database:postgresql".superuser;
          DATABASE_PASSWORD = "";
          DATABASE_SSL_REJECT_UNAUTHORIZED = "false";

          REDIS_HOST =
            if config.services.redis."database:redis".bind == null then
              "127.0.0.1"
            else
              config.services.redis."database:redis".bind;
          REDIS_PORT = toString config.services.redis."database:redis".port;
          REDIS_DB = "0";
          REDIS_USERNAME = "default";
          REDIS_PASSWORD = "";

          CLICKHOUSE_HOST = "127.0.0.1";
          CLICKHOUSE_PORT = toString config.services.clickhouse."database:clickhouse".extraConfig.http_port;
          CLICKHOUSE_USER = "default";
          CLICKHOUSE_PASSWORD = "password";
          CLICKHOUSE_DATABASE = "oneuptime";
        }
        //
          lib.optionalAttrs
            (
              (config.services.alloy."telemetry:alloy".enable or false)
              || (config.services.openobserve."openobserve".enable or false)
            )
            {
              OPENTELEMETRY_EXPORTER_OTLP_ENDPOINT = lib.removeSuffix "/v1/traces" (self.lib.mkOtelEnv lib config.services)
              .OTEL_EXPORTER_OTLP_TRACES_ENDPOINT;
              OPENTELEMETRY_EXPORTER_OTLP_HEADERS =
                (self.lib.mkOtelEnv lib config.services).OTEL_EXPORTER_OTLP_HEADERS or "";
            };
      };

      services.oneuptime-runner."oneuptime:runner" =
        with config.services.oneuptime-app."oneuptime:app";
        with extraEnvironment;
        {
          enable = true;
          package = self.packages.${pkgs.stdenv.hostPlatform.system}.oneuptime-runner;
          oneuptimeUrl = "${HTTP_PROTOCOL}://${listenAddress}:${APP_PORT}";
          extraEnvironment.ONEUPTIME_SECRET = ONEUPTIME_SECRET;
        };

      services.oneuptime-probe."oneuptime:probe-1" =
        with config.services.oneuptime-app."oneuptime:app";
        with extraEnvironment;
        {
          enable = true;
          package = self.packages.${pkgs.stdenv.hostPlatform.system}.oneuptime-probe;
          oneuptimeUrl = "${HTTP_PROTOCOL}://${listenAddress}:${APP_PORT}";
          extraEnvironment.REGISTER_PROBE_KEY = REGISTER_PROBE_KEY;
        };

      services.nginx."proxies:nginx" =
        with config.services.nginx."proxies:nginx";
        with self.packages.${pkgs.stdenv.hostPlatform.system};
        {
          port = oneuptime-ingress.passthru.port;

          eventsConfig = "worker_connections 16384;";

          httpConfig = "include ${
            assert oneuptime-ingress.passthru.dataDir == dataDir;
            assert oneuptime-ingress.passthru.appPort == config.services.oneuptime-app."oneuptime:app".port;
            oneuptime-ingress
          };";
        };

      settings.processes."proxies:nginx" = {
        depends_on."oneuptime:app".condition = "process_healthy";
        log_location = "${config.services.nginx."proxies:nginx".dataDir}/nginx.log";
      };

      settings.processes."proxies:nginx-test" = {
        namespace = config.services.nginx."proxies:nginx".namespace;
        command = pkgs.writeShellApplication {
          name = "proxies-nginx-test";
          runtimeInputs = [ pkgs.curl ];
          text = ''
            curl -fsS "http://127.0.0.1:${
              toString config.services.nginx."proxies:nginx".port
            }/status" > /dev/null

            curl -fsSL --max-redirs 3 "http://127.0.0.1:${
              toString config.services.nginx."proxies:nginx".port
            }/accounts" | head -c 15 | grep -qF '<!DOCTYPE html'
          '';
        };
        depends_on."proxies:nginx".condition = "process_healthy";
      };

      settings.processes."oneuptime:app".environment = {
        RUN_DATABASE_MIGRATIONS_ON_BOOT = "false";
      };

      settings.processes."oneuptime:app".log_location = "${
        config.services.oneuptime-app."oneuptime:app".dataDir
      }/app.log";

      settings.processes."oneuptime:runner".depends_on."oneuptime:app".condition = "process_healthy";

      settings.processes."oneuptime:runner".log_location = "${
        config.services.oneuptime-runner."oneuptime:runner".dataDir
      }/runner.log";

      settings.processes."oneuptime:probe-1".depends_on."oneuptime:app".condition = "process_healthy";

      settings.processes."oneuptime:probe-1".log_location = "${
        config.services.oneuptime-probe."oneuptime:probe-1".dataDir
      }/probe.log";

      settings.processes."oneuptime:app-migrate".depends_on = {
        "database:postgresql".condition = "process_healthy";
        "database:redis".condition = "process_healthy";
        "database:clickhouse".condition = "process_healthy";
      };

      settings.processes."oneuptime:clickhouse-replicas-test" =
        with config.services.oneuptime-app."oneuptime:app".extraEnvironment;
        with config.services.clickhouse."database:clickhouse";
        {
          namespace = config.services.oneuptime-app."oneuptime:app".namespace;
          environment.TZ = "UTC";
          command = pkgs.writeShellApplication {
            name = "oneuptime-clickhouse-replicas-test";
            runtimeInputs = [
              package
              pkgs.coreutils
            ];
            text = ''
              query() {
                clickhouse-client --port ${toString port} --user '${CLICKHOUSE_USER}' \
                  --password '${CLICKHOUSE_PASSWORD}' --query "$1"
              }
              replicas=0
              for _ in $(seq 1 30); do
                replicas=$(query "SELECT count() FROM system.replicas WHERE database = '${CLICKHOUSE_DATABASE}'")
                if [ "$replicas" -gt 0 ]; then
                  break
                fi
                sleep 1
              done
              test "$replicas" -gt 0
              readonly_replicas=1
              for _ in $(seq 1 30); do
                readonly_replicas=$(query "SELECT count() FROM system.replicas WHERE database = '${CLICKHOUSE_DATABASE}' AND is_readonly")
                if [ "$readonly_replicas" -eq 0 ]; then
                  break
                fi
                sleep 1
              done
              test "$readonly_replicas" -eq 0
            '';
          };
          depends_on."oneuptime:app-migrate".condition = "process_completed_successfully";
        };

      settings.processes."oneuptime:app-test" = {
        namespace = config.services.oneuptime-app."oneuptime:app".namespace;
        command = pkgs.writeShellApplication {
          name = "oneuptime-app-test";
          runtimeInputs = [ pkgs.curl ];
          text = ''
            curl -fsS "http://${config.services.oneuptime-app."oneuptime:app".listenAddress}:${
              toString config.services.oneuptime-app."oneuptime:app".port
            }/status" > /dev/null
          '';
        };
        depends_on."oneuptime:app".condition = "process_healthy";
      };
    };

  perSystem =
    { pkgs, lib, ... }@perSystemArgs:
    {

      process-compose.oneuptime.imports = [
        inputs.services-flake.processComposeModules.default
        config.flake.processComposeModules.database
        config.flake.processComposeModules.proxies
        config.flake.processComposeModules.oneuptime
        ./_test.nix
      ];

      packages.oneuptime-test = pkgs.writeShellApplication {
        name = "oneuptime-test";
        text = ''
          export PC_DISABLE_TUI=1
          exec ${lib.getExe perSystemArgs.config.process-compose.oneuptime.outputs.testPackage} "$@"
        '';
      };
    };
}
