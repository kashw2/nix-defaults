{ config, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.oneuptime-infrastructure-agent = pkgs.buildGoModule (finalAttrs: {
        pname = "oneuptime-infrastructure-agent";
        inherit (config.flake.lib.oneuptime pkgs) version src;

        __structuredAttrs = true;

        sourceRoot = "${finalAttrs.src.name}/agents/InfrastructureAgent";

        vendorHash = "sha256-44Z1GWZcSCh+AFfsxwJIMw9pqzgg2IuzkQEpCUOephk=";

        meta = (config.flake.lib.oneuptime pkgs).meta // {
          description = "Agent that reports host metrics to a OneUptime server";
          mainProgram = "oneuptime-infrastructure-agent";
          platforms = pkgs.lib.platforms.unix ++ pkgs.lib.platforms.windows;
        };
      });
    };
}
