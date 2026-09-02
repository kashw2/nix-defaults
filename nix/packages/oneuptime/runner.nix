_: {
  perSystem =
    { pkgs, lib, ... }:
    {
      packages.oneuptime-runner = pkgs.stdenv.mkDerivation (finalAttrs: {
        pname = "oneuptime-runner";
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

        preBuild = ''
          npmRoot=Runner npmDeps=${
            pkgs.fetchNpmDeps {
              name = "oneuptime-runner-npm-deps";
              src = "${finalAttrs.src}/Runner";
              hash = "sha256-5rbZYNqX6cyF13ULg9TWtCXmzk8w4IwZdVhvmJfNEqc=";
            }
          } npmConfigHook
        '';

        buildPhase = ''
          runHook preBuild
          cd Runner
          npm run compile
          cd -
          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          mkdir -p $out
          cp -a Common $out/Common
          cp -a Runner $out/app
          runHook postInstall
        '';

        passthru.runtimeEnv = {
          TS_NODE_TRANSPILE_ONLY = "1";
          PRODUCTION = "true";
        };

        meta = {
          description = "OneUptime workflow and code-fix runner";
          homepage = "https://oneuptime.com";
          license = lib.licenses.asl20;
          platforms = lib.platforms.unix;
        };
      });
    };
}
