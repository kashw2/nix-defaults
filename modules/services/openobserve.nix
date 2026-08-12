{ inputs, config, ... }:
{
  # `multiService` registers the `services.openobserve` type from ./_openobserve
  # (juspay/services-flake#713). Bundled with the enable module so the exported
  # module stays self-contained; drop the `multiService` import once the PR lands.
  # TODO: This can be idiomatic import and definition when the above pr is merged upstream
  flake.processComposeModules.openobserve = {
    imports = [
      (inputs.services-flake.lib.multiService ./_openobserve/openobserve.nix)
      (_: {
        services.openobserve."openobserve".enable = true;
      })
    ];
  };

  perSystem = _: {
    process-compose.openobserve.imports = [
      inputs.services-flake.processComposeModules.default
      config.flake.processComposeModules.openobserve
      ./_test.nix
    ];
  };
}
