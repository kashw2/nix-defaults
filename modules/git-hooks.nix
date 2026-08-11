{ inputs, ... }:
let
  git-hooks = {
    imports = [
      inputs.git-hooks-nix.flakeModule
    ];

    perSystem = { config, pkgs, ... }: {
      pre-commit.settings.hooks = {
        treefmt = {
          enable = true;
          packageOverrides.treefmt = config.treefmt.build.wrapper;
        };
        commitizen.enable = true;
        flake-checker.enable = true;
        check-merge-conflicts.enable = true;
        check-added-large-files.enable = true;
        end-of-file-fixer.enable = true;
        trim-trailing-whitespace.enable = true;
      };
      # Without this devShell the hooks are never installed into .git/hooks
      devShells.git-hooks = pkgs.mkShell {
        shellHook = config.pre-commit.installationScript;
      };
    };
  };
in
{
  imports = [ git-hooks ];
  flake.flakeModules.git-hooks = git-hooks;
}
