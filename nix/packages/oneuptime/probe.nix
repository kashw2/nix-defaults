{ config, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.oneuptime-probe = (config.flake.lib.oneuptime pkgs).workspacePackage {
        workspace = "Probe";
        hash = "sha256-G3AAe4J4Yh/Fz6pHOgxpcWBbpPnnIeiKQHYd2Iyz3oM=";
        description = "OneUptime synthetic and network monitoring probe";

        runtimeEnv = {
          PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
          PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
        };

        extraAttrs.npmRebuildFlags = [ "--ignore-scripts" ];
      };
    };
}
