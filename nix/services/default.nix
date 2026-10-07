{
  inputs,
  config,
  lib,
  ...
}:
let
  processComposeModules = builtins.attrValues config.flake.processComposeModules;
in
{
  imports = [
    inputs.process-compose-flake.flakeModule
  ];

  perSystem =
    { pkgs, config, ... }:
    {
      process-compose.default.imports = [
        inputs.services-flake.processComposeModules.default
        # This imoports tests and allows us to implement it as part of a working flake check
        ./_test.nix
        (
          { config, ... }:
          {
            # Without setting the addr to the loopback it fails in the nix sandbox.
            # Use the ingester lifecycler rather than the segment-writer one: the latter
            # only exists on pyroscope 2.x, while this flag is accepted by both.
            services.pyroscope."telemetry:pyroscope".extraFlags = [
              "-ingester.lifecycler.addr=${config.services.pyroscope."telemetry:pyroscope".httpAddress}"
            ];
          }
        )
      ]
      ++ processComposeModules;

      packages.test = pkgs.writeShellApplication {
        name = "test";
        text = ''
          export PC_DISABLE_TUI=1
          exec ${lib.getExe config.process-compose.default.outputs.testPackage} "$@"
        '';
      };
    };
}
