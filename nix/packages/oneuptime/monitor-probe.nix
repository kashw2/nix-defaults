_: {
  perSystem =
    { pkgs, ... }:
    {
      packages.oneuptime-monitor-probe-attacher = pkgs.writeShellApplication {
        name = "oneuptime-monitor-probe-attacher";

        runtimeInputs = [
          pkgs.curl
          pkgs.jq
          pkgs.coreutils
        ];

        excludeShellChecks = [ "SC2016" ];

        text = ''
          api="$ONEUPTIME_URL/api"

          check=0
          if [ "''${1:-}" = "--check" ]; then
            check=1
          fi

          login=$(curl -sS -w '\n%{http_code}' -X POST "$api/identity/login" \
            -H 'Content-Type: application/json' \
            --data "$(jq -nc --arg email "$ONEUPTIME_ADMIN_EMAIL" --arg password "$ONEUPTIME_ADMIN_PASSWORD" \
              '{data: {email: {_type: "Email", value: $email}, password: {_type: "HashedString", value: $password}}}')")

          if [ "''${login##*$'\n'}" -ge 400 ]; then
            echo "monitor-probe-attach: logging in as $ONEUPTIME_ADMIN_EMAIL answered ''${login##*$'\n'}: ''${login%$'\n'*}" >&2
            exit 1
          fi

          token=$(jq -r '._miscData.accessToken // empty' <<<"''${login%$'\n'*}")

          if [ -z "$token" ]; then
            echo "monitor-probe-attach: logging in as $ONEUPTIME_ADMIN_EMAIL returned no access token" >&2
            exit 1
          fi

          api_post() {
            local scope=() response status body

            if [ -n "$2" ]; then
              scope=(-H "projectid: $2")
            fi

            response=$(curl -sS -w '\n%{http_code}' -X POST "$api$1" \
              -H "Authorization: Bearer $token" \
              -H 'Content-Type: application/json' \
              "''${scope[@]}" --data "$3")

            status=''${response##*$'\n'}
            body=''${response%$'\n'*}

            if [ "$status" -ge 400 ]; then
              echo "monitor-probe-attach: POST $1 answered $status: $body" >&2
              return 1
            fi

            printf '%s' "$body"
          }

          lookup() {
            api_post "$1/get-list" "$2" \
              "$(jq -nc --argjson query "$3" '{query: $query, select: {_id: true}, limit: 1, skip: 0}')" \
              | jq -r '.data[0]._id // empty'
          }

          project_id=""
          if [ -n "$ONEUPTIME_MONITOR_PROJECT" ]; then
            project_id=$(lookup "/project" "" "$(jq -nc --arg name "$ONEUPTIME_MONITOR_PROJECT" '{name: $name}')")

            if [ -z "$project_id" ]; then
              echo "monitor-probe-attach: project $ONEUPTIME_MONITOR_PROJECT does not exist" >&2
              exit 1
            fi
          fi

          probe_names="$ONEUPTIME_PROBE_NAMES"
          probe_count=$(jq 'length' <<<"$probe_names")
          probes="{}"

          if [ "$probe_count" -gt 0 ]; then
            echo "monitor-probe-attach: waiting for global probe(s) $probe_names to register"

            for attempt in $(seq 1 60); do
              listing=$(api_post "/probe/global-probes" "" \
                "$(jq -nc '{query: {}, select: {_id: true, name: true}, limit: 100, skip: 0}')") || exit 1

              probes=$(jq -c --argjson names "$probe_names" \
                '[.data[] | select(.name as $n | $names | index($n) != null)] | map({(.name): ._id}) | add // {}' \
                <<<"$listing")

              if [ "$(jq 'length' <<<"$probes")" -eq "$probe_count" ]; then
                echo "monitor-probe-attach: all probe(s) registered after $attempt attempt(s)"
                break
              fi

              echo "monitor-probe-attach: attempt $attempt/60 - not all probe(s) registered yet, retrying in 5s"
              sleep 5
            done

            if [ "$(jq 'length' <<<"$probes")" -ne "$probe_count" ]; then
              missing=$(jq -nc --argjson probes "$probes" --argjson names "$probe_names" '$names - ($probes | keys)')
              echo "monitor-probe-attach: timed out after 300s waiting for global probe(s) $missing to register" >&2
              exit 1
            fi
          fi

          mapfile -t monitor_values < <(jq -r '.[]' <<<"$ONEUPTIME_MONITOR_VALUES")
          mapfile -t probe_ids < <(jq -r '.[]' <<<"$probes")

          status=0

          for value in "''${monitor_values[@]}"; do
            monitor_id=$(lookup "/monitor" "$project_id" \
              "$(jq -nc --arg field "$ONEUPTIME_MONITOR_IDENTIFIER" --arg value "$value" '{($field): $value}')")

            if [ -z "$monitor_id" ]; then
              echo "monitor-probe-attach: monitor $value does not exist" >&2
              status=1
              continue
            fi

            for probe_id in "''${probe_ids[@]}"; do
              existing=$(lookup "/monitor-probe" "$project_id" \
                "$(jq -nc --arg monitorId "$monitor_id" --arg probeId "$probe_id" '{monitorId: $monitorId, probeId: $probeId}')")

              if [ -n "$existing" ]; then
                continue
              fi

              if [ "$check" -eq 1 ]; then
                echo "monitor-probe-attach: monitor $value has no MonitorProbe row for probe $probe_id" >&2
                status=1
                continue
              fi

              api_post "/monitor-probe" "$project_id" \
                "$(jq -nc --arg projectId "$project_id" --arg monitorId "$monitor_id" --arg probeId "$probe_id" \
                  '{data: {projectId: $projectId, monitorId: $monitorId, probeId: $probeId, isEnabled: true}}')" > /dev/null \
                || status=1

              echo "monitor-probe-attach: attached probe $probe_id to monitor $value"
            done
          done

          if [ "$status" -eq 0 ]; then
            echo "monitor-probe-attach: done"
          fi

          exit "$status"
        '';
      };
    };
}
