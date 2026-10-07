{ config, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.oneuptime-app = pkgs.buildNpmPackage (finalAttrs: {
        pname = "oneuptime-app";
        inherit (config.flake.lib.oneuptime pkgs) version src;

        __structuredAttrs = true;

        sourceRoot = "${finalAttrs.src.name}/packages/App";

        nodejs = pkgs.nodejs_26;

        npmDepsHash = "sha256-tmU0Q1ETPqkrZPr3uATZshhtrhfqoSve06V4tzT2hEE=";

        nativeBuildInputs = [ pkgs.makeWrapper ];

        postPatch = ''
          # unpackPhase only makes sourceRoot writable, and Common sits outside it.
          chmod -R u+w ..

          substituteInPlace FeatureSet/Dashboard/src/Components/SessionReplay/ReplayStage.tsx \
            --replace-fail "img-src data: blob:;" "img-src data: blob: http: https:;"

          substituteInPlace FeatureSet/Telemetry/Services/OtelProfilesIngestService.ts \
            --replace-fail 'const date: Date = OneUptimeDate.fromUnixNano(numericValue);' 'let date: Date = OneUptimeDate.fromUnixNano(numericValue); if (Number.isNaN(date.getTime())) { numericValue = OneUptimeDate.getCurrentDateAsUnixNano(); date = OneUptimeDate.fromUnixNano(numericValue); }'

          substituteInPlace FeatureSet/Dashboard/src/Components/Exceptions/ExceptionsDashboard.tsx \
            --replace-fail 'import Service from "Common/Models/DatabaseModels/Service";' 'import Service from "Common/Models/DatabaseModels/Service"; import RumApplication from "Common/Models/DatabaseModels/RumApplication";' \
            --replace-fail 'setServices(result.data);' 'const rumResult: ListResult<RumApplication> = await ModelAPI.getList<RumApplication>({ modelType: RumApplication, query: { projectId: ProjectUtil.getCurrentProjectId()! }, select: { _id: true, name: true }, sort: { name: SortOrder.Ascending }, skip: 0, limit: LIMIT_PER_PROJECT }); setServices([...result.data, ...rumResult.data.map((app: RumApplication): Service => { const rumService: Service = new Service(); rumService.id = app.id!; rumService.name = app.name || ""; return rumService; })]);'

          # ExceptionsViewer loads its five model lists in one Promise.all, so the
          # RUM applications are fetched alongside it rather than in place of it.
          substituteInPlace FeatureSet/Dashboard/src/Components/Exceptions/ExceptionsViewer.tsx \
            --replace-fail 'import Service from "Common/Models/DatabaseModels/Service";' 'import Service from "Common/Models/DatabaseModels/Service"; import RumApplication from "Common/Models/DatabaseModels/RumApplication";' \
            --replace-fail 'setServices(serviceResult.data || []);' 'const rumResult: ModelListResult<RumApplication> = await ModelAPI.getList<RumApplication>({ modelType: RumApplication, query: { projectId }, limit: LIMIT_PER_PROJECT, skip: 0, select: { _id: true, name: true }, sort: { name: SortOrder.Ascending } }); setServices([...(serviceResult.data || []), ...(rumResult.data || []).map((app: RumApplication): Service => { const rumService: Service = new Service(); rumService.id = app.id!; rumService.name = app.name || ""; return rumService; })]);'
        '';

        # Common and the six frontends are separate npm projects that depend on
        # each other by path, so each needs its own deps.
        preBuild = pkgs.lib.concatLines (
          pkgs.lib.mapAttrsToList
            (dir: deps: ''
              (
                cd ../${dir}
                # npmConfigHook requires both lockfiles to be identical, so take the
                # repaired one back out of the fetched deps.
                cp ${deps}/package-lock.json package-lock.json
                export npmDeps=${deps}
                npmConfigHook
              )
            '')
            (
              builtins.mapAttrs
                (
                  dir: hash:
                  pkgs.fetchNpmDeps {
                    name = "oneuptime-${pkgs.lib.toLower (baseNameOf dir)}-npm-deps-${finalAttrs.version}";
                    src = "${finalAttrs.src}/packages/${dir}";
                    # Upstream ships some of these lockfiles without `resolved`/`integrity` on a chunk of their entries, which cannot be fetched
                    nativeBuildInputs = [ pkgs.npm-lockfile-fix ];
                    preBuild = "npm-lockfile-fix package-lock.json";
                    inherit hash;
                  }
                )
                {
                  "Common" = "sha256-TuFMlTUbWKlqLmm4nDR0Nxye2w0acmngFDFvfXkmkIQ=";
                  "App/FeatureSet/Accounts" = "sha256-s3FMX9Q18ul+9Mozi6bCbjh+XJuLBSxVAWEflftB62c=";
                  "App/FeatureSet/AdminDashboard" = "sha256-2tecXiNkajkuyp95QdEvHtYi3a/5P7SK7bD+3dMDT/4=";
                  "App/FeatureSet/BrowserRecorder" = "sha256-2ySF3/FNe4Om1g/8q4N+Ws9IcumS64/IUuKoiLqJFAI=";
                  "App/FeatureSet/Dashboard" = "sha256-ZTx1mqBlB8ewzLCzPdgPxTGguEPLbJ/NaKR6O/fs2sQ=";
                  "App/FeatureSet/PublicDashboard" = "sha256-ZWqJJd5d+MrzafhriFSBcGfrWYCaudyQ623N4VFcKhU=";
                  "App/FeatureSet/StatusPage" = "sha256-Khlu2UFugyhEcROuREucPmaK+Rc9ft/kfvAeI4Z9C3I=";
                }
            )
        );

        npmBuildScript = "build-frontends:prod";

        # The Dashboard service worker bakes both into its cache key at build time,
        # falling back to md5(Date.now()), which would make $out unreproducible.
        env = {
          GIT_SHA = finalAttrs.version;
          APP_VERSION = finalAttrs.version;
        };

        postBuild = ''
          # The same generator stamps a wall-clock timestamp nothing reads.
          sed -i 's/^ \* Generated at: .*/ * Generated at: (reproducible build)/' \
            FeatureSet/Dashboard/public/sw.js
        '';

        installPhase = ''
          runHook preInstall

          install -d $out/lib/oneuptime
          cp -a ../Common $out/lib/oneuptime/Common
          cp -a . $out/lib/oneuptime/App

          # Some FeatureSets and Common resolve views, assets and docs against the Docker image's WORKDIR rather than their own location.
          find $out/lib/oneuptime -type f \( -name '*.ts' -o -name '*.ejs' \) \
            -not -path '*/node_modules/*' -not -path '*/Tests/*' \
            -exec sed -i \
              "s#/usr/src/app#$out/lib/oneuptime/App#g; s#/usr/src/Common#$out/lib/oneuptime/Common#g" {} +

          makeWrapper ${pkgs.lib.getExe pkgs.nodejs_26} $out/bin/oneuptime-app \
            --chdir $out/lib/oneuptime/App \
            --add-flags "--no-node-snapshot --require ts-node/register $out/lib/oneuptime/App/Index.ts" \
            --set TS_NODE_TRANSPILE_ONLY 1 \
            --set PRODUCTION true \
            --set APP_VERSION ${finalAttrs.version}

          makeWrapper ${pkgs.lib.getExe pkgs.nodejs_26} $out/bin/oneuptime-app-migrate \
            --chdir $out/lib/oneuptime/App \
            --add-flags "--no-node-snapshot --require ts-node/register $out/lib/oneuptime/App/Migrate.ts" \
            --set TS_NODE_TRANSPILE_ONLY 1 \
            --set PRODUCTION true \
            --set APP_VERSION ${finalAttrs.version}

          runHook postInstall
        '';

        meta = (config.flake.lib.oneuptime pkgs).meta // {
          description = "OneUptime app monolith — dashboard, API, workers and telemetry ingestion";
          mainProgram = "oneuptime-app";
          platforms = pkgs.lib.platforms.linux;
        };
      });
    };
}
