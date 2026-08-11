{ inputs, ... }:
let
  # Process-compose stacks exposed as reusable modules. Anything added here is imported into the `default` stack
  # and exported on the flake so a downstream consumer can drop pieces with removeAttrs.
  processComposeModules = {
    lgtm = ./_lgtm.nix;
    telemetry = ./_telemetry.nix;
    # `multiService` registers the `services.openobserve` type from ./_openobserve
    # (juspay/services-flake#713). Bundled with the enable module so the exported
    # module stays self-contained; drop the `multiService` import once the PR lands.
    # TODO: This can be idiomatic import and definition when the above pr is merged upstream
    openobserve = {
      imports = [
        (inputs.services-flake.lib.multiService ./_openobserve/openobserve.nix)
        ./_openobserve.nix
      ];
    };
  };
in
{
  imports = [
    inputs.process-compose-flake.flakeModule
  ];

  flake.processComposeModules = processComposeModules;

  perSystem = { ... }: {
    process-compose."default" = {
      imports = [
        inputs.services-flake.processComposeModules.default
      ]
      ++ builtins.attrValues processComposeModules;
    };
  };
}
