{ config, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.oneuptime-kubernetes-cost-agent = pkgs.buildNpmPackage (finalAttrs: {
        pname = "oneuptime-kubernetes-cost-agent";
        inherit (config.flake.lib.oneuptime pkgs) version src;

        __structuredAttrs = true;

        sourceRoot = "${finalAttrs.src.name}/agents/KubernetesCostAgent";

        nodejs = pkgs.nodejs_26;

        npmDepsHash = "sha256-KHAezDX8aFIGvhnzb3CWC7nF47sJQ6RMt2V97eqBSnQ=";

        npmBuildScript = "compile";

        nativeBuildInputs = [ pkgs.makeWrapper ];

        installPhase = ''
          runHook preInstall

          install -d $out/lib/oneuptime-kubernetes-cost-agent
          cp -a build/dist $out/lib/oneuptime-kubernetes-cost-agent/

          makeWrapper ${pkgs.lib.getExe pkgs.nodejs_26} $out/bin/oneuptime-kubernetes-cost-agent \
            --add-flags $out/lib/oneuptime-kubernetes-cost-agent/dist/Index.js

          runHook postInstall
        '';

        meta = (config.flake.lib.oneuptime pkgs).meta // {
          description = "Agent that reports Kubernetes workload cost allocations to OneUptime";
          mainProgram = "oneuptime-kubernetes-cost-agent";
          platforms = pkgs.lib.platforms.linux;
        };
      });
    };
}
