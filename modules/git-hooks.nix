{ inputs, ... }:
let
  git-hooks = {
    imports = [
      inputs.git-hooks-nix.flakeModule
    ];

    perSystem = { config, ... }: {
      pre-commit.settings.hooks.treefmt = {
        enable = true;
        packageOverrides.treefmt = config.treefmt.build.wrapper;
      };
    };
  };
in
{
  imports = [ git-hooks ];
  flake.flakeModules.git-hooks = git-hooks;
}
