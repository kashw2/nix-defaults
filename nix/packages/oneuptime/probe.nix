_: {
  perSystem =
    { pkgs, lib, ... }:
    {
      packages.oneuptime-probe = pkgs.stdenv.mkDerivation (finalAttrs: {
        pname = "oneuptime-probe";
        version = "12.0.28";

        src = pkgs.fetchFromGitHub {
          owner = "OneUptime";
          repo = "oneuptime";
          tag = finalAttrs.version;
          hash = "sha256-vOLlBXJL6/7fNgkDm5DYpfMtE2fEGywzts1m4Gtd5Jk=";
        };

        nativeBuildInputs = [
          pkgs.nodejs_26
          pkgs.nodejs_26.passthru.python
          pkgs.npmHooks.npmConfigHook
        ];

        npmDeps = pkgs.fetchNpmDeps {
          name = "oneuptime-common-npm-deps";
          src = "${finalAttrs.src}/Common";
          hash = "sha256-d15gMaOGPuij5TLTN64+LpJdptTcVihm454gVKtHsyg=";
        };
        npmRoot = "Common";

        PRODUCTION = "true";
        PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
        npm_config_foreground_scripts = "true";
        npmRebuildFlags = [ "--ignore-scripts" ];

        preBuild = ''
          npmRoot=Probe npmDeps=${
            pkgs.fetchNpmDeps {
              name = "oneuptime-probe-npm-deps";
              src = "${finalAttrs.src}/Probe";
              hash = "sha256-G3AAe4J4Yh/Fz6pHOgxpcWBbpPnnIeiKQHYd2Iyz3oM=";
            }
          } npmConfigHook
        '';

        buildPhase = ''
          runHook preBuild
          cd Probe
          npm run compile
          cd -
          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          mkdir -p $out
          cp -a Common $out/Common
          cp -a Probe $out/app
          runHook postInstall
        '';

        passthru.runtimeEnv = {
          TS_NODE_TRANSPILE_ONLY = "1";
          PRODUCTION = "true";
          PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
          PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
        };

        meta = {
          description = "OneUptime synthetic and network monitoring probe";
          homepage = "https://oneuptime.com";
          license = lib.licenses.asl20;
          platforms = lib.platforms.unix;
        };
      });
    };
}
