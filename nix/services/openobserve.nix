{ inputs, config, ... }:
{
  flake.processComposeModules.openobserve =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      options.openobserve.dashboards = lib.mkOption {
        type = lib.types.listOf lib.types.path;
        default = [ ];
        description = "Paths to OpenObserve dashboard JSON files to import on startup.";
      };

      config = {
        services.openobserve."openobserve" = {
          enable = true;
          extraEnvironment = {
            ZO_COMPACT_DATA_RETENTION_DAYS = "7";
            ZO_RUM_ENABLED = "true";
          };
        };

        settings.processes."openobserve-dashboard" = lib.mkIf (config.openobserve.dashboards != [ ]) (
          with config.services.openobserve."openobserve";
          {
            command = pkgs.writeShellApplication {
              name = "openobserve-dashboard";
              runtimeInputs = [
                pkgs.curl
                pkgs.jq
                pkgs.findutils
              ];
              text = lib.concatMapStrings (
                dashboard:
                (title: api: curl: ''
                  ${curl} '${api}' | jq -r '.dashboards[] | select(.v5.title == "${title}") | .dashboardId' \
                    | xargs -r -I{} ${curl} -X DELETE '${api}/{}' > /dev/null
                  ${curl} -H 'Content-Type: application/json' -X POST --data-binary @${dashboard} '${api}' > /dev/null
                  echo "dashboard ${title}: imported"
                '')
                  (builtins.fromJSON (builtins.readFile dashboard)).title
                  "http://${httpAddress}:${toString httpPort}/api/default/dashboards"
                  "curl -fsS -u '${extraEnvironment.ZO_ROOT_USER_EMAIL or "admin@services-flake.com"}:${
                    extraEnvironment.ZO_ROOT_USER_PASSWORD or "Admin1!@"
                  }'"
              ) config.openobserve.dashboards;
            };
            depends_on."openobserve".condition = "process_healthy";
            availability.restart = "exit_on_failure";
          }
        );
      };
    };

  perSystem = _: {
    process-compose.openobserve.imports = [
      inputs.services-flake.processComposeModules.default
      config.flake.processComposeModules.openobserve
      { openobserve.dashboards = [ ./_openobserve/dashboard.json ]; }
    ];
  };
}
