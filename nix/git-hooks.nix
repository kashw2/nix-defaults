{ inputs, ... }:
let
  git-hooks = {
    imports = [
      inputs.git-hooks-nix.flakeModule
    ];

    perSystem =
      {
        config,
        pkgs,
        lib,
        ...
      }:
      {
        options.preCommit.configFile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = ".pre-commit-config.yaml";
          description = ''
            Repo-relative path to a consumer-supplied .pre-commit-config.yaml.

            When null (default), this flake generates and installs the
            pre-commit config from the Nix-defined hooks below.

            When set, the Nix-defined hooks are disabled entirely and the
            git-hooks devShell installs the plain pre-commit tool against the
            given working-tree file, letting non-Nix developers maintain their
            own config.
          '';
        };

        config = lib.mkMerge [
          (lib.mkIf (config.preCommit.configFile == null) {
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
            # Installs the hooks into .git/hooks
            devShells.git-hooks = pkgs.mkShell {
              shellHook = config.pre-commit.installationScript;
            };
          })
          (lib.mkIf (config.preCommit.configFile != null) {
            # Consumer owns the config, disable Nix generation and the sandboxed check
            pre-commit.settings.enable = false;
            pre-commit.check.enable = false;
            devShells.git-hooks = pkgs.mkShell {
              packages = [
                pkgs.pre-commit
                pkgs.git
              ];
              shellHook = ''
                # Clear any core.hooksPath (e.g. from a prior Nix-generated install)
                # so `pre-commit install` doesn't cowardly refuse.
                ${lib.getExe pkgs.git} config --local --unset-all core.hooksPath 2>/dev/null || true
                ${lib.getExe pkgs.pre-commit} install --config ${config.preCommit.configFile}
                ${lib.getExe pkgs.pre-commit} install-hooks --config ${config.preCommit.configFile}
              '';
            };
          })
        ];
      };
  };
in
{
  imports = [ git-hooks ];
  flake.flakeModules.git-hooks = git-hooks;
}
