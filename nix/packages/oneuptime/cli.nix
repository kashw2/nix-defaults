{ config, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.oneuptime-cli = pkgs.buildNpmPackage (finalAttrs: {
        pname = "oneuptime-cli";
        inherit (config.flake.lib.oneuptime pkgs) version src;

        __structuredAttrs = true;

        sourceRoot = "${finalAttrs.src.name}/packages/CLI";

        nodejs = pkgs.nodejs_26;

        npmDepsHash = "sha256-Ue2FqYPEtkxRAvWaoNxgivCEKhlU9NO4OUoL5PmAVuM=";

        nativeBuildInputs = [ pkgs.esbuild ];

        nativeInstallCheckInputs = [ pkgs.versionCheckHook ];
        doInstallCheck = true;

        # unpackPhase only makes sourceRoot writable, and Common sits outside it.
        postPatch = ''
          chmod -R u+w ..
        '';

        # CLI depends on Common as `file:../Common`, so npm symlinks it rather
        # than installing it, and CLI's own lockfile does not carry Common's
        # dependencies — tsc compiles Common's sources, so they have to be there.
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

        # tsc type-checks Common's sources but emits only CLI's own, so Common is
        # compiled here. It emits ESM with extensionless relative imports, which
        # Node's ESM resolver rejects, so esbuild rewrites it to CommonJS in place.
        postBuild = ''
          (
            cd ../Common

            npm run compile

            find build/dist -name '*.js' -exec esbuild \
              --format=cjs \
              --platform=node \
              --outbase=build/dist \
              --outdir=. \
              --log-level=error \
              {} +

            rm -rf build
          )
        '';

        # npm installs Common as a symlink out of the build tree, which dangles
        # once the package is copied into $out.
        postInstall = ''
          rm $out/lib/node_modules/@oneuptime/cli/node_modules/Common
          cp -a ../Common $out/lib/node_modules/@oneuptime/cli/node_modules/Common
        '';

        versionCheckProgramArg = "version";

        meta = (config.flake.lib.oneuptime pkgs).meta // {
          description = "Command-line interface for managing OneUptime resources";
          mainProgram = "oneuptime";
          platforms = pkgs.lib.platforms.all;
        };
      });
    };
}
