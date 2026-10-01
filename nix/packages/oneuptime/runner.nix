{ config, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.oneuptime-runner = pkgs.buildNpmPackage (finalAttrs: {
        pname = "oneuptime-runner";
        inherit (config.flake.lib.oneuptime pkgs) version src;

        __structuredAttrs = true;

        sourceRoot = "${finalAttrs.src.name}/packages/Runner";

        nodejs = pkgs.nodejs_26;

        npmDepsHash = "sha256-j8pIsmae7RXH1oMX/48mlpp2Bix7s1R2ztb+neWP/QI=";

        nativeBuildInputs = [ pkgs.makeWrapper ];

        # unpackPhase only makes sourceRoot writable, and Common sits outside it.
        postPatch = ''
          chmod -R u+w ..
        '';

        # Runner depends on Common as `file:../Common`, so npm symlinks it rather than installing it.
        preBuild = ''
          (
            cd ../Common
            export npmDeps=${
              pkgs.fetchNpmDeps {
                name = "oneuptime-common-npm-deps-${finalAttrs.version}";
                src = "${finalAttrs.src}/packages/Common";
                hash = "sha256-APolLZbF0BWeN/bkSMelVOjc4TUEBlwcPcniq5+Ba1Y=";
              }
            }
            npmConfigHook
          )
        '';

        dontNpmBuild = true;

        installPhase = ''
          runHook preInstall

          install -d $out/lib/oneuptime
          cp -a ../Common $out/lib/oneuptime/Common
          cp -a . $out/lib/oneuptime/Runner

          makeWrapper ${pkgs.lib.getExe pkgs.nodejs_26} $out/bin/oneuptime-runner \
            --chdir $out/lib/oneuptime/Runner \
            --add-flags "--no-node-snapshot --require ts-node/register $out/lib/oneuptime/Runner/Index.ts" \
            --set TS_NODE_TRANSPILE_ONLY 1 \
            --set PRODUCTION true \
            --set APP_VERSION ${finalAttrs.version} \
            --prefix PATH : ${
              # Runbook steps run under bash, it also supports code fixes which run under git
              pkgs.lib.makeBinPath [
                pkgs.bash
                pkgs.git
              ]
            }

          runHook postInstall
        '';

        meta = (config.flake.lib.oneuptime pkgs).meta // {
          description = "OneUptime workflow and code-fix runner";
          mainProgram = "oneuptime-runner";
          platforms = pkgs.lib.platforms.linux;
        };
      });
    };
}
