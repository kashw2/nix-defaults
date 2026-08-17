{ inputs, config, ... }:
{
  flake.processComposeModules.storage =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      options.seaweedfs.buckets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "S3 bucket names to create in SeaweedFS on startup.";
      };

      config = {
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

        settings.processes."storage:seaweedfs-provision" = lib.mkIf (config.seaweedfs.buckets != [ ]) {
          command = pkgs.writeShellApplication {
            name = "seaweedfs-provision";
            runtimeInputs = [ config.services.seaweedfs."storage:seaweedfs".package ];
            text = ''
              weed shell -master=127.0.0.1:9333 <<'EOF'
              ${lib.concatMapStringsSep "\n" (b: "s3.bucket.create -name ${b}") config.seaweedfs.buckets}
              EOF
            '';
          };
          depends_on."storage:seaweedfs".condition = "process_healthy";
        };

        settings.processes."storage:seaweedfs-test" = lib.mkIf (config.seaweedfs.buckets != [ ]) {
          command = pkgs.writeShellApplication {
            name = "seaweedfs-test";
            runtimeInputs = [ config.services.seaweedfs."storage:seaweedfs".package ];
            excludeShellChecks = [ "SC2043" ];
            text = ''
              for bucket in ${lib.escapeShellArgs config.seaweedfs.buckets}; do
                weed shell -master=127.0.0.1:9333 <<< 's3.bucket.list' | grep -w "$bucket"
              done
            '';
          };
          depends_on."storage:seaweedfs-provision".condition = "process_completed_successfully";
        };
      };
    };

  perSystem = _: {
    process-compose.storage.imports = [
      inputs.services-flake.processComposeModules.default
      config.flake.processComposeModules.storage
      { seaweedfs.buckets = [ "test-bucket" ]; }
      ./_test.nix
    ];
  };
}
