{
  flake.lib.oneuptime = pkgs: rec {
    version = "12.0.28";

    src = pkgs.fetchFromGitHub {
      owner = "OneUptime";
      repo = "oneuptime";
      tag = version;
      hash = "sha256-vOLlBXJL6/7fNgkDm5DYpfMtE2fEGywzts1m4Gtd5Jk=";
    };

    meta = {
      homepage = "https://oneuptime.com";
      license = pkgs.lib.licenses.asl20;
      platforms = pkgs.lib.platforms.unix;
    };

    workspacePackage =
      {
        workspace,
        hash,
        description,
        runtimeEnv ? { },
        extraAttrs ? { },
      }:
      pkgs.stdenv.mkDerivation (
        finalAttrs:
        {
          pname = "oneuptime-${pkgs.lib.toLower workspace}";
          inherit version src;

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
            npmRoot=${workspace} npmDeps=${
              pkgs.fetchNpmDeps {
                name = "${finalAttrs.pname}-npm-deps";
                src = "${finalAttrs.src}/${workspace}";
                inherit hash;
              }
            } npmConfigHook
          '';

          buildPhase = ''
            runHook preBuild
            cd ${workspace}
            npm run compile
            cd -
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            mkdir -p $out
            cp -a Common $out/Common
            cp -a ${workspace} $out/app
            runHook postInstall
          '';

          passthru.runtimeEnv = {
            TS_NODE_TRANSPILE_ONLY = "1";
            PRODUCTION = "true";
          }
          // runtimeEnv;

          meta = meta // {
            inherit description;
          };
        }
        // extraAttrs
      );
  };
}
