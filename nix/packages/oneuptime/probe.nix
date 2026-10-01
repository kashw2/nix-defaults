{ config, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.oneuptime-probe = pkgs.buildNpmPackage (finalAttrs: {
        pname = "oneuptime-probe";
        inherit (config.flake.lib.oneuptime pkgs) version src;

        __structuredAttrs = true;

        sourceRoot = "${finalAttrs.src.name}/packages/Probe";

        nodejs = pkgs.nodejs_26;

        npmDepsHash = "sha256-HbMI7ZfS+5I16nTEWUZQ1evRRlinI41/5RNpwdkvpP8=";

        # The one optional dependency is msnodesqlv8, a native driver needing unixODBC.
        npmFlags = [ "--omit=optional" ];

        nativeBuildInputs = [ pkgs.makeWrapper ];

        # Probe depends on Common as `file:../Common`, so npm symlinks it rather
        # than installing it, and Common still needs the optional dependencies
        # Probe omits.
        preBuild = ''
          chmod -R u+w ../Common

          (
            export npmRoot=../Common
            export npmDeps=${
              pkgs.fetchNpmDeps {
                name = "oneuptime-common-npm-deps-${finalAttrs.version}";
                src = "${finalAttrs.src}/packages/Common";
                hash = "sha256-APolLZbF0BWeN/bkSMelVOjc4TUEBlwcPcniq5+Ba1Y=";
              }
            }
            npmFlags=""
            npmFlagsArray=()

            npmConfigHook
          )
        '';

        dontNpmBuild = true;

        # NPM's playwright fetches browsers from a postinstall the sandbox blocks. Replace it with nixpkgs's own
        postBuild = ''
          for pkg in playwright playwright-core; do
            rm -rf node_modules/$pkg
            cp -r --no-preserve=mode ${pkgs.playwright-test}/lib/node_modules/$pkg node_modules/$pkg
          done
        '';

        installPhase = ''
          runHook preInstall

          install -d $out/lib/oneuptime
          cp -a ../Common $out/lib/oneuptime/Common
          cp -a . $out/lib/oneuptime/Probe

          makeWrapper ${pkgs.lib.getExe pkgs.nodejs_26} $out/bin/oneuptime-probe \
            --chdir $out/lib/oneuptime/Probe \
            --add-flags "--no-node-snapshot" \
            --add-flags "--require ts-node/register" \
            --add-flags $out/lib/oneuptime/Probe/Index.ts \
            --set TS_NODE_TRANSPILE_ONLY 1 \
            --set PRODUCTION true \
            --set APP_VERSION ${finalAttrs.version} \
            --set PLAYWRIGHT_BROWSERS_PATH ${
              # Synthetic monitoring doesn't use webkit and disabling reclaims 1GB
              pkgs.playwright-driver.browsers.override { withWebkit = false; }
            } \
            --prefix PATH : ${
              # Monitors shell out to these for networking checks
              pkgs.lib.makeBinPath [
                pkgs.dnsutils
                pkgs.iputils
                pkgs.traceroute
              ]
            }

          runHook postInstall
        '';

        meta = (config.flake.lib.oneuptime pkgs).meta // {
          description = "OneUptime synthetic and network monitoring probe";
          mainProgram = "oneuptime-probe";
          platforms = pkgs.lib.platforms.linux;
        };
      });
    };
}
