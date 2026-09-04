self:
{
  config,
  pkgs,
  lib,
  ...
}:
{
  options.oneuptime.provisioning = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, ... }:
        {
          options = {
            sources = lib.mkOption {
              type = lib.types.listOf lib.types.path;
              default = [ ];
              description = "JSON files, one record each.";
            };

            project = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default =
                if
                  name == "project" || (builtins.length (config.oneuptime.provisioning.project.sources or [ ])) != 1
                then
                  null
                else
                  (builtins.fromJSON (
                    builtins.readFile (builtins.head config.oneuptime.provisioning.project.sources)
                  )).name;
              description = "Project these records belong to. Defaults to the one declared under `project`, null when there is not exactly one.";
            };

            identifier = lib.mkOption {
              type = lib.types.str;
              default = "name";
              description = "Field records are looked up by, to create or update.";
            };
          };
        }
      )
    );
    default = { };
    description = ''
      Records to provision, keyed by API path segment: `dashboard` POSTs to
      /api/dashboard. A `{"$ref": {"kind": _, "name": _}}` anywhere in a record
      becomes that record's id, and waits for it, so kinds need no order.
    '';
    example = {
      project.sources = [ ./project.json ];
      dashboard = {
        project = "Default";
        sources = [ ./dashboard.json ];
      };
    };
  };

  config.settings.processes = lib.mkIf (config.oneuptime.provisioning != { }) {
    "oneuptime:provisioning" =
      with config.services.oneuptime-app."oneuptime:app";
      with extraEnvironment;
      {
        inherit namespace;

        command = lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.oneuptime-provisioner;

        environment = {
          ONEUPTIME_URL = "${HTTP_PROTOCOL}://${listenAddress}:${APP_PORT}";
          ONEUPTIME_ADMIN_EMAIL = admin.email;
          ONEUPTIME_ADMIN_PASSWORD = admin.password;

          ONEUPTIME_PROVISIONING_MANIFEST = "${pkgs.writeText "oneuptime-provisioning.json" (
            builtins.toJSON (
              lib.mapAttrsToList (kind: entry: entry // { inherit kind; }) config.oneuptime.provisioning
            )
          )}";
        };

        depends_on."oneuptime:provision".condition = "process_completed_successfully";
        availability.restart = "exit_on_failure";
      };

    "oneuptime:provisioning-test" = with config.settings.processes."oneuptime:provisioning"; {
      inherit namespace environment;

      command = "${command} --check";

      depends_on."oneuptime:provisioning".condition = "process_completed_successfully";
    };
  };
}
