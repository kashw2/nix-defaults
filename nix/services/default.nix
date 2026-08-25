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
        # Imports tests and allows us to implement it as part of a working flake check
        ./_test.nix
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
