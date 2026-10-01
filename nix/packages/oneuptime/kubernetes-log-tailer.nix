{ config, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.oneuptime-kubernetes-log-tailer = pkgs.buildNpmPackage (finalAttrs: {
        pname = "oneuptime-kubernetes-log-tailer";
        inherit (config.flake.lib.oneuptime pkgs) version src;

        __structuredAttrs = true;

        sourceRoot = "${finalAttrs.src.name}/agents/KubernetesLogTailer";

        nodejs = pkgs.nodejs_26;

        npmDepsHash = "sha256-JdXOoZhn2626Ylt6vtqKQ+cBRRzlIAYTTPq8PjacE8c=";

        npmBuildScript = "compile";

        # Prevent inclusion of dev deps since we override installPhase
        npmFlags = [ "--omit=dev" ];

        nativeBuildInputs = [ pkgs.makeWrapper ];

        installPhase = ''
          runHook preInstall

          install -d $out/lib/oneuptime-kubernetes-log-tailer
          cp -a build/dist node_modules $out/lib/oneuptime-kubernetes-log-tailer/

          makeWrapper ${pkgs.lib.getExe pkgs.nodejs_26} $out/bin/oneuptime-kubernetes-log-tailer \
            --add-flags $out/lib/oneuptime-kubernetes-log-tailer/dist/Index.js

          runHook postInstall
        '';

        meta = (config.flake.lib.oneuptime pkgs).meta // {
          description = "Agent that forwards Kubernetes pod logs to OneUptime via OTLP";
          mainProgram = "oneuptime-kubernetes-log-tailer";
          platforms = pkgs.lib.platforms.linux;
        };
      });
    };
}
