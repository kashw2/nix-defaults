_: {
  perSystem =
    { pkgs, ... }:
    {
      packages.oneuptime-provisioner = pkgs.writeShellApplication {
        name = "oneuptime-provisioner";

        runtimeInputs = [
          pkgs.curl
          pkgs.jq
          pkgs.coreutils
        ];

        excludeShellChecks = [ "SC2016" ];

        text = ''
          api="$ONEUPTIME_URL/api"
          manifest="$ONEUPTIME_PROVISIONING_MANIFEST"

          check=0
          if [ "''${1:-}" = "--check" ]; then
            check=1
          fi

          report=0

          login=$(curl -sS -w '\n%{http_code}' -X POST "$api/identity/login" \
            -H 'Content-Type: application/json' \
            --data "$(jq -nc --arg email "$ONEUPTIME_ADMIN_EMAIL" --arg password "$ONEUPTIME_ADMIN_PASSWORD" \
              '{data: {email: {_type: "Email", value: $email}, password: {_type: "HashedString", value: $password}}}')")

          if [ "''${login##*$'\n'}" -ge 400 ]; then
            echo "provisioning: logging in as $ONEUPTIME_ADMIN_EMAIL answered ''${login##*$'\n'}: ''${login%$'\n'*}" >&2
            exit 1
          fi

          token=$(jq -r '._miscData.accessToken // empty' <<<"''${login%$'\n'*}")

          if [ -z "$token" ]; then
            echo "provisioning: logging in as $ONEUPTIME_ADMIN_EMAIL returned no access token" >&2
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
              echo "provisioning: POST $1 answered $status: $body" >&2
              return 1
            fi

            printf '%s' "$body"
          }

          lookup() {
            api_post "$1/get-list" "$2" \
              "$(jq -nc --arg field "$3" --arg value "$4" \
                '{query: {($field): $value}, select: {_id: true}, limit: 1, skip: 0}')" \
              | jq -r '.data[0]._id // empty'
          }

          kind_field() {
            jq -r --arg kind "$1" --arg field "$2" \
              'first(.[] | select(.kind == $kind) | .[$field]) // "" | tostring' "$manifest"
          }

          scope_for() {
            local id=$2

            if [ -n "$1" ]; then
              id=$(lookup "/project" "" "name" "$1") || return 1

              if [ -z "$id" ]; then
                if [ "$report" -eq 1 ]; then
                  echo "provisioning: $3 is waiting on a project named $1 that does not exist" >&2
                fi

                return 2
              fi
            fi

            printf '%s' "$id"
          }

          resolve() {
            local json map refs ref kind name identifier project scope id

            json=$(cat "$1")
            map='{}'
            mapfile -t refs < <(jq -c '[.. | objects | select(has("$ref")) | .["$ref"]] | unique | .[]' <<<"$json")

            for ref in "''${refs[@]}"; do
              kind=$(jq -r '.kind' <<<"$ref")
              name=$(jq -r '.name' <<<"$ref")
              identifier=$(kind_field "$kind" identifier)
              project=$(kind_field "$kind" project)

              scope=$(scope_for "$project" "$2" "$1") || return $?

              id=$(lookup "/$kind" "$scope" "''${identifier:-name}" "$name") || return 1

              if [ -z "$id" ]; then
                if [ "$report" -eq 1 ]; then
                  echo "provisioning: $1 references the $kind named $name, which does not exist" >&2
                fi

                return 2
              fi

              map=$(jq -c --argjson ref "$ref" --arg id "$id" '. + {($ref | tojson): $id}' <<<"$map")
            done

            jq -c --argjson map "$map" \
              'walk(if type == "object" and has("$ref") then $map[(.["$ref"] | tojson)] else . end)' <<<"$json"
          }

          provision() {
            local fields kind identifier project source scope data value id stored changes

            mapfile -t fields < <(jq -r '.kind, .identifier, .project, .source' <<<"$1")
            kind=''${fields[0]}
            identifier=''${fields[1]}
            project=''${fields[2]}
            source=''${fields[3]}

            scope=$(scope_for "$project" "" "$source") || return $?
            data=$(resolve "$source" "$scope") || return $?

            value=$(jq -r --arg field "$identifier" '.[$field] // empty' <<<"$data")

            if [ -z "$value" ]; then
              echo "provisioning: $source has no $identifier to look it up by" >&2
              return 1
            fi

            id=$(lookup "/$kind" "$scope" "$identifier" "$value") || return 1

            stored='{}'
            if [ -n "$id" ]; then
              stored=$(api_post "/$kind/get-list" "$scope" \
                "$(jq -nc --arg field "$identifier" --arg value "$value" \
                  --argjson select "$(jq -c '[keys[] | {(.): true}] | add + {_id: true}' <<<"$data")" \
                  '{query: {($field): $value}, select: $select, limit: 1, skip: 0}')" \
                | jq -c '.data[0] // {}') || return 1
            fi

            if [ "$check" -eq 1 ]; then
              if [ -z "$id" ]; then
                echo "provisioning: $kind $value was never created" >&2
                return 1
              fi

              if grep -qF '"$ref"' <<<"$stored"; then
                echo "provisioning: $kind $value kept an unresolved reference" >&2
                return 1
              fi

              return 0
            fi

            if [ -z "$id" ]; then
              api_post "/$kind" "$scope" "$(jq -nc --argjson data "$data" '{data: $data}')" > /dev/null || return 1
              return 0
            fi

            changes=$(jq -nc --argjson data "$data" --argjson stored "$stored" \
              '[$data | to_entries[] | select($stored[.key] != .value)] | from_entries')

            if [ "$changes" = "{}" ]; then
              return 0
            fi

            api_post "/$kind/$id/update-item" "$scope" \
              "$(jq -nc --argjson changes "$changes" '{data: $changes}')" > /dev/null || return 1
          }

          mapfile -t pending < <(jq -c '.[] as $entry | $entry.sources[] | {kind: $entry.kind, identifier: $entry.identifier, project: ($entry.project // ""), source: .}' "$manifest")

          while [ "''${#pending[@]}" -gt 0 ]; do
            deferred=()
            progress=0

            for item in "''${pending[@]}"; do
              status=0
              provision "$item" || status=$?

              if [ "$status" -eq 0 ]; then
                progress=$((progress + 1))
              elif [ "$status" -eq 2 ]; then
                deferred+=("$item")
              else
                exit 1
              fi
            done

            if [ "''${#deferred[@]}" -eq 0 ]; then
              break
            fi

            if [ "$progress" -eq 0 ]; then
              report=1

              for item in "''${deferred[@]}"; do
                provision "$item" || true
              done

              exit 1
            fi

            pending=("''${deferred[@]}")
          done
        '';
      };
    };
}
