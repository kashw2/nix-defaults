{ inputs, ... }:
{
  imports = [
    inputs.process-compose-flake.flakeModule
  ];

  perSystem = { ... }: {
    process-compose."services" = {
      imports = [
        inputs.services-flake.processComposeModules.default
      ];
    };
  };
}
