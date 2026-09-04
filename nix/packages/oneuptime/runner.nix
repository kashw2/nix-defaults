{ config, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.oneuptime-runner = (config.flake.lib.oneuptime pkgs).workspacePackage {
        workspace = "Runner";
        hash = "sha256-5rbZYNqX6cyF13ULg9TWtCXmzk8w4IwZdVhvmJfNEqc=";
        description = "OneUptime workflow and code-fix runner";
      };
    };
}
