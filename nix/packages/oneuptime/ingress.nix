{ config, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.oneuptime-ingress = pkgs.stdenv.mkDerivation (finalAttrs: {
        pname = "oneuptime-ingress";
        inherit (config.flake.lib.oneuptime pkgs) version src;

        nativeBuildInputs = [
          pkgs.gettext
          pkgs.nginx
        ];

        passthru = {
          port = 7849;
          appPort = 3002;
          dataDir = "./data/proxies:nginx";
        };

        buildCommand = ''
          export HOST=127.0.0.1
          export APP_PORT=${toString finalAttrs.passthru.appPort}
          export HOME_PORT=${toString finalAttrs.passthru.appPort}
          export SERVER_APP_HOSTNAME=127.0.0.1
          export SERVER_HOME_HOSTNAME=127.0.0.1
          export BACKEND_APP_TARGET='$backend_app'
          export BACKEND_APP_GRPC_TARGET='$backend_app_grpc'
          export BILLING_ENABLED=false
          export NGINX_LISTEN_ADDRESS=127.0.0.1:
          export NGINX_INGEST_ACCESS_LOG=on
          export NGINX_RESOLVER=127.0.0.1
          export SERVER_NAMES_HASH_BUCKET_SIZE=128
          export SERVER_NAMES_HASH_MAX_SIZE=2048

          sed '/# BEGIN upstream-keepalive/,/# END upstream-keepalive/d' \
            ${finalAttrs.src}/Nginx/default.conf.template > template

          envsubst "$(grep -oE '\$\{[A-Z_][A-Z0-9_]*\}' template | sort -u | tr '\n' ' ')" \
            < template \
            | sed \
              -e 's#/var/log/nginx/#${finalAttrs.passthru.dataDir}/#g' \
              -e 's#/etc/nginx/certs/#${finalAttrs.passthru.dataDir}/certs/#g' \
              -e 's#^\([[:space:]]*listen[[:space:]][^;]*[^0-9]\)7849\([^0-9]\)#\1${toString finalAttrs.passthru.port}\2#' \
            > servers.conf

          ! grep -qE '\$\{[A-Z_]' servers.conf

          sed -n '/^http {/,$p' ${finalAttrs.src}/Nginx/nginx.conf \
            | sed \
              -e '1d' \
              -e '$d' \
              -e '/include[[:space:]]*\/etc\/nginx\/mime\.types;/d' \
              -e '/include[[:space:]]*\/etc\/nginx\/conf\.d\/default\.conf;/d' \
              -e 's#/var/log/nginx/#${finalAttrs.passthru.dataDir}/#g' \
            > http.conf

          cat http.conf servers.conf > $out

          mkdir -p ${finalAttrs.passthru.dataDir}/nginx ${finalAttrs.passthru.dataDir}/certs
          {
            echo 'pid nginx.pid;'
            echo 'events { }'
            echo 'http {'
            cat $out
            echo '}'
          } > check.conf
          nginx -t -p . -c check.conf -e stderr
        '';

        meta = (config.flake.lib.oneuptime pkgs).meta // {
          description = "OneUptime nginx ingress configuration, for an nginx http block";
        };
      });
    };
}
