_: {
  perSystem =
    { pkgs, lib, ... }:
    {
      packages.oneuptime-app = pkgs.stdenv.mkDerivation (finalAttrs: {
        pname = "oneuptime-app";
        version = "12.0.28";

        src = pkgs.stdenv.mkDerivation (nodeModules: {
          pname = "oneuptime-app-node-modules";
          inherit (finalAttrs) version;

          src = pkgs.fetchFromGitHub {
            owner = "OneUptime";
            repo = "oneuptime";
            tag = nodeModules.version;
            hash = "sha256-vOLlBXJL6/7fNgkDm5DYpfMtE2fEGywzts1m4Gtd5Jk=";
          };

          nativeBuildInputs = [ pkgs.nodejs_26 ];

          dontConfigure = true;
          dontFixup = true;

          PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
          SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
          NODE_EXTRA_CA_CERTS = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
          npm_config_progress = "false";

          buildPhase = ''
            runHook preBuild

            export HOME=$NIX_BUILD_TOP/home
            export npm_config_cache=$NIX_BUILD_TOP/npm-cache
            mkdir -p $HOME $npm_config_cache

            for tree in \
              Common \
              App \
              App/FeatureSet/Accounts \
              App/FeatureSet/Dashboard \
              App/FeatureSet/AdminDashboard \
              App/FeatureSet/StatusPage \
              App/FeatureSet/PublicDashboard \
              App/FeatureSet/BrowserRecorder; do
              ( cd $tree && npm ci --no-audit --no-fund --ignore-scripts )
            done

            rm -rf $npm_config_cache $HOME
            find . -type d -name _logs -prune -exec rm -rf {} +
            find . -type d -name .npm -prune -exec rm -rf {} +
            find . -name 'npm-debug.log*' -delete

            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            mkdir -p $out
            cp -a Common $out/Common
            cp -a App $out/App
            runHook postInstall
          '';

          outputHashMode = "recursive";
          outputHashAlgo = "sha256";
          outputHash = "sha256-Lf+GEj/7LinIut02WYpStjAzQ5OBne+gAsNoaw7txIk=";
        });

        nativeBuildInputs = [
          pkgs.nodejs_26
          pkgs.nodejs_26.passthru.python
        ];

        unpackPhase = ''
          runHook preUnpack
          cp -a "$src" source
          chmod -R u+w source
          cd source
          runHook postUnpack
        '';

        dontConfigure = true;

        PRODUCTION = "true";
        PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
        npm_config_foreground_scripts = "true";
        npm_config_offline = "true";
        npm_config_nodedir = "${pkgs.nodejs_26}";

        preBuild = ''
          find App Common -type f \( -name '*.ts' -o -name '*.ejs' \) \
            -not -path '*/node_modules/*' -not -path '*/Tests/*' \
            -exec sed -i "s#/usr/src/app#$out/app#g; s#/usr/src/Common#$out/Common#g" {} +

          export HOME=$NIX_BUILD_TOP/home
          export npm_config_cache=$NIX_BUILD_TOP/npm-cache
          mkdir -p $HOME $npm_config_cache

          for tree in \
            Common \
            App \
            App/FeatureSet/Accounts \
            App/FeatureSet/Dashboard \
            App/FeatureSet/AdminDashboard \
            App/FeatureSet/StatusPage \
            App/FeatureSet/PublicDashboard \
            App/FeatureSet/BrowserRecorder; do
            (
              cd $tree
              patchShebangs node_modules
              npm rebuild --no-audit --no-fund
              patchShebangs node_modules
            )
          done

          for tree in \
            App/FeatureSet/Accounts \
            App/FeatureSet/Dashboard \
            App/FeatureSet/AdminDashboard \
            App/FeatureSet/StatusPage \
            App/FeatureSet/PublicDashboard \
            App/FeatureSet/BrowserRecorder; do
            if ! npm --prefix $tree ls --depth=0 > /dev/null; then
              exit 1
            fi
          done
        '';

        buildPhase = ''
          runHook preBuild
          cd App
          export GIT_SHA=${finalAttrs.version}
          export APP_VERSION=${finalAttrs.version}
          npm run build-frontends:prod
          npm run compile
          cd -
          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          mkdir -p $out
          cp -a Common $out/Common
          cp -a App $out/app
          runHook postInstall
        '';

        passthru.runtimeEnv = {
          TS_NODE_TRANSPILE_ONLY = "1";
          PRODUCTION = "true";
        };

        meta = {
          description = "OneUptime app monolith — dashboard, API, workers and telemetry ingestion";
          homepage = "https://oneuptime.com";
          license = lib.licenses.asl20;
          platforms = lib.platforms.unix;
        };
      });
    };
}
