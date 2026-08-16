{ inputs, config, ... }:
{
  flake.processComposeModules.storage =
    { config, pkgs, ... }:
    {
      services.seaweedfs."storage:seaweedfs" = {
        enable = true;
        filer.enable = true;
        s3 = {
          enable = true;
          # Default identity so S3 clients have working credentials out of the
          # box. Override by pointing `s3.config` at a different file.
          config = pkgs.writeText "seaweedfs-s3.json" (
            builtins.toJSON {
              identities = [
                {
                  name = "default";
                  credentials = [
                    {
                      accessKey = "seaweedfsadmin";
                      secretKey = "seaweedfsadmin";
                    }
                  ];
                  actions = [
                    "Admin"
                    "Read"
                    "Write"
                  ];
                }
              ];
            }
          );
        };
        # The upstream module has no metricsPort option, so pass it through.
        # Keep this port in sync with the scrape target in telemetry.nix.
        # TODO: drop once services.seaweedfs gains a metricsPort option upstream.
        extraArgs = [ "-metricsPort=9494" ];
      };
      # SeaweedFS logs to stderr (glog); its `-logdir` flag must precede the
      # `server` subcommand so it cannot go through extraArgs. Redirect the
      # process output to a stable file instead so Alloy can tail it.
      settings.processes."storage:seaweedfs".log_location = "${
        config.services.seaweedfs."storage:seaweedfs".dataDir
      }/seaweedfs.log";
    };

  perSystem = _: {
    process-compose.storage.imports = [
      inputs.services-flake.processComposeModules.default
      config.flake.processComposeModules.storage
      ./_test.nix
    ];
  };
}
