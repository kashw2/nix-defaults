self:
{
  config,
  pkgs,
  lib,
  ...
}:
{
  options.oneuptime.attachMonitorProbes = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Attach every enabled probe to every provisioned monitor once
      provisioning completes. A monitor with no probe attached never
      checks anything, and looks correctly configured while doing so -
      disable only if monitors are meant to be probed from elsewhere.
    '';
  };

  config.settings.processes =
    lib.mkIf
      (
        config.oneuptime.attachMonitorProbes
        && (config.oneuptime.provisioning.monitor.sources or [ ]) != [ ]
      )
      (
        with config.services.oneuptime-app."oneuptime:app";
        with extraEnvironment;
        {
          "oneuptime:monitor-probe-attach" = {
            inherit namespace;

            command =
              lib.getExe
                self.packages.${pkgs.stdenv.hostPlatform.system}.oneuptime-monitor-probe-attacher;

            environment = {
              ONEUPTIME_URL = "${HTTP_PROTOCOL}://${listenAddress}:${APP_PORT}";
              ONEUPTIME_ADMIN_EMAIL = admin.email;
              ONEUPTIME_ADMIN_PASSWORD = admin.password;

              ONEUPTIME_PROBE_NAMES = builtins.toJSON (
                lib.attrNames (lib.filterAttrs (_: v: v.enable) config.services.oneuptime-probe)
              );

              ONEUPTIME_MONITOR_PROJECT = config.oneuptime.provisioning.monitor.project or "";
              ONEUPTIME_MONITOR_IDENTIFIER = config.oneuptime.provisioning.monitor.identifier;

              ONEUPTIME_MONITOR_VALUES = builtins.toJSON (
                map (
                  src: (builtins.fromJSON (builtins.readFile src)).${config.oneuptime.provisioning.monitor.identifier}
                ) config.oneuptime.provisioning.monitor.sources
              );
            };

            depends_on = {
              "oneuptime:provisioning".condition = "process_completed_successfully";
            }
            // lib.mapAttrs (_: _: { condition = "process_healthy"; }) (
              lib.filterAttrs (_: v: v.enable) config.services.oneuptime-probe
            );

            availability.restart = "exit_on_failure";
          };

          "oneuptime:monitor-probe-attach-test" =
            with config.settings.processes."oneuptime:monitor-probe-attach"; {
              inherit namespace environment;

              command = "${command} --check";

              depends_on."oneuptime:monitor-probe-attach".condition = "process_completed_successfully";
            };
        }
      );
}
