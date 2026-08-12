{
  inputs,
  config,
  ...
}:
{
  imports = [
    inputs.process-compose-flake.flakeModule
  ];

  perSystem = ps: {
    process-compose.default.imports = [
      inputs.services-flake.processComposeModules.default
      ./_test.nix
    ]
    ++ builtins.attrValues config.flake.processComposeModules;

    packages.test = ps.config.process-compose.default.outputs.testPackage;
  };
}
