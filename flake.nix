{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs-ruby = {
      url = "github:bobvanderlinden/nixpkgs-ruby";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      pre-commit-hooks,
      nixpkgs-ruby,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ nixpkgs-ruby.overlays.default ];
        };

        rubyVersion = builtins.head (builtins.split "\n" (builtins.readFile ./.ruby-version));
        ruby = pkgs."ruby-${rubyVersion}";

        pgBase = pkgs.postgresql_18;
        pgConfig = pgBase.pg_config;
        postgresql = pgBase.withPackages (ps: [ ps.pgvector ]);

        postgresqlBuildFlags = [
          "--with-pg-config=${pgConfig}/bin/pg_config"
        ];
        psychBuildFlags = with pkgs; [
          "--with-libyaml-include=${libyaml.dev}/include"
          "--with-libyaml-lib=${libyaml.out}/lib"
        ];
        zlibBuildFlags = with pkgs; [
          "--with-zlib-include=${zlib.dev}/include"
          "--with-zlib-lib=${zlib.out}/lib"
        ];

        # Worktree detection hook (per-flake, reusable pattern)
        # Disable Git fsmonitor for hook-local probes. If these git commands start
        # fsmonitor--daemon inside direnv's shellHook, the daemon can inherit a
        # nix-direnv pipe and keep the first `direnv exec ...` blocked after setup.
        worktree = rec {
          isWorktree = ''
            if git -c core.fsmonitor=false rev-parse --is-inside-work-tree >/dev/null 2>&1; then
              if [ "$(git -c core.fsmonitor=false rev-parse --git-dir 2>/dev/null)" != "$(git -c core.fsmonitor=false rev-parse --git-common-dir 2>/dev/null)" ]; then
                echo "true"
              else
                echo "false"
              fi
            else
              echo "false"
            fi
          '';

          id = ''
            if [ "$(${isWorktree})" = "true" ]; then
              git -c core.fsmonitor=false rev-parse --show-toplevel | md5sum | cut -c1-8
            else
              echo "main"
            fi
          '';
        };

        pg-environment-variables = ''
          if [ "$(${worktree.isWorktree})" = "true" ]; then
            WT_ID=$(${worktree.id})
            export PGHOST="/tmp/pg-$WT_ID"
            export PGDATA="$HOME/.local/share/postgres/worktrees/$WT_ID"
            mkdir -p "$PGHOST" "$PGDATA"
          else
            export PGDATA=$PWD/.nix/postgres/data
            export PGHOST=$PWD/.nix/postgres
          fi
          export DB_USER=""
        '';

        postgresql-start = pkgs.writeShellScriptBin "pg-start" ''
          ${pg-environment-variables}

          if [ ! -f "$PGDATA/PG_VERSION" ]; then
            mkdir -p "$PGDATA"
            ${postgresql}/bin/initdb "$PGDATA" --auth=trust
          fi

          ${postgresql}/bin/postgres \
            -k "$PGHOST" \
            -c listen_addresses=''' \
            -c unix_socket_directories="$PGHOST" \
            -c max_wal_size=16GB \
            -c maintenance_work_mem=8GB
        '';

        worktree-info = pkgs.writeShellScriptBin "worktree-info" ''
          if [ "$(${worktree.isWorktree})" = "true" ]; then
            WT_ID=$(${worktree.id})
            echo "Worktree mode enabled"
            echo "  ID:          $WT_ID"
            echo "  PGHOST:      /tmp/pg-$WT_ID"
            echo "  PGDATA:      $HOME/.local/share/postgres/worktrees/$WT_ID"
          else
            echo "Normal checkout (not a worktree)"
          fi
        '';

        worktree-clean = pkgs.writeShellScriptBin "worktree-clean" ''
          set -euo pipefail
          if [ "$(${worktree.isWorktree})" != "true" ]; then
            echo "Not inside a worktree. Nothing to clean."
            exit 0
          fi

          WT_ID=$(${worktree.id})
          echo "Cleaning worktree $WT_ID..."

          PGDATA="$HOME/.local/share/postgres/worktrees/$WT_ID"
          PGHOST="/tmp/pg-$WT_ID"
          PIDFILE="/tmp/pg-$WT_ID.pid"

          # Stop the daemonised Postgres for this worktree before removing its data.
          if [ -f "$PGDATA/postmaster.pid" ] || [ -f "$PIDFILE" ]; then
            echo "    Stopping Postgres..."
            ${postgresql}/bin/pg_ctl stop -D "$PGDATA" -s -m fast || true
          fi

          rm -f "$PIDFILE"

          # Remove short socket dir and per-worktree Postgres data
          rm -rf "$PGHOST"
          rm -rf "$PGDATA"

          # Remove per-worktree Bundler and Nix state
          rm -rf ".bundle"
          rm -rf "$HOME/.local/share/gem/worktrees/$WT_ID" 2>/dev/null || true
          rm -rf "$HOME/.cache/bundle/worktrees/$WT_ID" 2>/dev/null || true
          rm -rf ".nix" 2>/dev/null || true

          # Remove marker
          rm -f "$HOME/.local/share/postgres/worktrees/$WT_ID/.worktree-initialized" 2>/dev/null || true

          echo "Worktree $WT_ID cleaned (Postgres + bundle + .nix)."
        '';

        opensearch-start = pkgs.writeShellScriptBin "opensearch-start" ''
                    set -euo pipefail

                    runtime_dir="$PWD/.nix/opensearch"
                    home="$runtime_dir/home"
                    config="$runtime_dir/config"
                    data="$runtime_dir/data"
                    logs="$runtime_dir/logs"
                    store_marker="$runtime_dir/store-path"

                    mkdir -p "$runtime_dir" "$config" "$data" "$logs"

                    if [ ! -f "$store_marker" ] || [ "$(cat "$store_marker")" != "${pkgs.opensearch}" ]; then
                      rm -rf "$home"
                      mkdir -p "$home/bin"

                      ln -sfn "${pkgs.opensearch}/agent" "$home/agent"
                      ln -sfn "${pkgs.opensearch}/lib" "$home/lib"
                      ln -sfn "${pkgs.opensearch}/modules" "$home/modules"
                      ln -sfn "${pkgs.opensearch}/plugins" "$home/plugins"

                      ${pkgs.gnused}/bin/sed "s|${pkgs.opensearch}|$home|g" \
                        "${pkgs.opensearch}/bin/.opensearch-wrapped" > "$home/bin/.opensearch-wrapped"
                      ${pkgs.gnused}/bin/sed "s|${pkgs.opensearch}|$home|g" \
                        "${pkgs.opensearch}/bin/opensearch-keystore" > "$home/bin/opensearch-keystore"

                      cp "${pkgs.opensearch}/bin/opensearch-env" "$home/bin/opensearch-env"
                      cp "${pkgs.opensearch}/bin/opensearch-env-from-file" "$home/bin/opensearch-env-from-file"
                      chmod +x "$home/bin/.opensearch-wrapped" "$home/bin/opensearch-keystore" \
                        "$home/bin/opensearch-env" "$home/bin/opensearch-env-from-file"

                      cat > "$home/bin/opensearch-cli" <<'OPENSEARCH_CLI'
          #!/usr/bin/env bash
          set -e -o pipefail

          source "$(dirname "$0")"/opensearch-env

          if [ -z "$OPENSEARCH_TMPDIR" ]; then
            OPENSEARCH_TMPDIR="$("$JAVA" "$XSHARE" -cp "$OPENSEARCH_CLASSPATH" org.opensearch.tools.launchers.TempDirectory)"
          fi

          if [ -n "''${OPENSEARCH_ADDITIONAL_CLASSPATH_DIRECTORIES:-}" ]; then
            for directory in $OPENSEARCH_ADDITIONAL_CLASSPATH_DIRECTORIES; do
              OPENSEARCH_CLASSPATH="$OPENSEARCH_CLASSPATH:$OPENSEARCH_HOME/$directory/*"
            done
          fi

          exec "$JAVA" "$XSHARE" \
            -Dopensearch.path.home="$OPENSEARCH_HOME" \
            -Dopensearch.path.conf="$OPENSEARCH_PATH_CONF" \
            -Dopensearch.distribution.type="$OPENSEARCH_DISTRIBUTION_TYPE" \
            -Dopensearch.bundled_jdk="$OPENSEARCH_BUNDLED_JDK" \
            -cp "$OPENSEARCH_CLASSPATH" \
            "$OPENSEARCH_MAIN_CLASS" \
            "$@"
          OPENSEARCH_CLI
                      chmod +x "$home/bin/opensearch-cli"

                      echo "${pkgs.opensearch}" > "$store_marker"
                    fi

                    ${pkgs.gnused}/bin/sed "s|logs/gc.log|$logs/gc.log|g" \
                      "${pkgs.opensearch}/config/jvm.options" > "$config/jvm.options"
                    rm -f "$config/opensearch.yml" "$config/log4j2.properties"
                    cp "${pkgs.opensearch}/config/opensearch.yml" "$config/opensearch.yml"
                    cp "${pkgs.opensearch}/config/log4j2.properties" "$config/log4j2.properties"

                    exec env \
                      JAVA_HOME="${pkgs.jdk21_headless.home}" \
                      OPENSEARCH_PATH_CONF="$config" \
                      OPENSEARCH_JAVA_OPTS="''${OPENSEARCH_JAVA_OPTS:--Xms512m -Xmx512m}" \
                      "$home/bin/.opensearch-wrapped" \
                      -E discovery.type=single-node \
                      -E plugins.security.disabled=true \
                      -E path.data="$data" \
                      -E path.logs="$logs" \
                      -E http.port="''${OPENSEARCH_PORT:-9200}" \
                      -E network.host="''${OPENSEARCH_HOST:-127.0.0.1}" \
                      "$@"
        '';

        redis-start = pkgs.writeShellScriptBin "redis-start" ''
          set -euo pipefail

          mkdir -p "$PWD/.nix/redis"

          exec ${pkgs.redis}/bin/redis-server \
            --dir "$PWD/.nix/redis" \
            --port "''${REDIS_PORT:-6379}" \
            --save "" \
            --appendonly no
        '';

        lint = pkgs.writeShellScriptBin "lint" ''
          mapfile -t changed_files < <(git diff --name-only --diff-filter=ACM --merge-base main)

          if [ ''${#changed_files[@]} -eq 0 ]; then
            echo "No changed files to lint."
            exit 0
          fi

          pre-commit run --files "''${changed_files[@]}"
        '';

        init = pkgs.writeShellScriptBin "init" ''
          cd terraform && terraform init -input=false -no-color -backend=false
        '';

        update-providers = pkgs.writeShellScriptBin "update-providers" ''
          cd terraform
          terraform init -backend=false -reconfigure -upgrade
        '';

        preCommitCheck = pre-commit-hooks.lib.${system}.run {
          src = ./.;
          configPath = ".pre-commit-config-nix.yaml";
          default_stages = [ "pre-commit" ];
          hooks = {
            actionlint = {
              enable = true;
              stages = [ "pre-commit" ];
            };
            check-added-large-files = {
              enable = true;
              stages = [ "pre-commit" ];
            };
            check-case-conflicts = {
              enable = true;
              stages = [ "pre-commit" ];
            };
            check-merge-conflicts = {
              enable = true;
              stages = [ "pre-commit" ];
            };
            check-yaml = {
              enable = true;
              excludes = [
                "^db/"
                "^config/sidekiq\\.yml$"
              ];
              stages = [ "pre-commit" ];
            };
            deadnix = {
              enable = true;
              stages = [ "pre-commit" ];
            };
            detect-private-keys = {
              enable = true;
              stages = [ "pre-commit" ];
            };
            end-of-file-fixer = {
              enable = true;
              excludes = [
                "^db/"
                "^config/credentials\\.yml\\.enc$"
              ];
              stages = [ "pre-commit" ];
            };
            nixfmt-rfc-style = {
              package = pre-commit-hooks.inputs.nixpkgs.legacyPackages.${system}.nixfmt;
              enable = true;
              stages = [ "pre-commit" ];
            };
            shellcheck = {
              enable = true;
              args = [ "--severity=warning" ];
              stages = [ "pre-commit" ];
            };
            sort-file-contents = {
              enable = true;
              files = "^\\.env\\.(development|test)$";
              stages = [ "pre-commit" ];
            };
            statix = {
              enable = true;
              settings.ignore = [ "{.direnv,.nix,.worktrees}/**" ];
              stages = [ "pre-commit" ];
            };
            terraform-format = {
              enable = true;
              package = pkgs.terraform;
              stages = [ "pre-commit" ];
            };
            terraform-validate = {
              enable = true;
              package = pkgs.terraform;
              entry = ''
                bash -c '
                  set -uo pipefail
                  status=0

                  while read -r dir; do
                    lockfile="$dir/.terraform.lock.hcl"
                    backup=$(mktemp)
                    had_lockfile=false

                    if [ -f "$lockfile" ]; then
                      cp "$lockfile" "$backup"
                      had_lockfile=true
                    fi

                    ${pkgs.terraform}/bin/terraform -chdir="$dir" init -backend=false
                    init_status=$?

                    if [ "$init_status" -eq 0 ]; then
                      ${pkgs.terraform}/bin/terraform -chdir="$dir" validate
                      validate_status=$?
                    else
                      validate_status=$init_status
                    fi

                    if [ "$had_lockfile" = true ]; then
                      cp "$backup" "$lockfile"
                    else
                      rm -f "$lockfile"
                    fi
                    rm -f "$backup"

                    if [ "$validate_status" -ne 0 ]; then
                      status=$validate_status
                    fi
                  done < <(for arg in "$@"; do dirname "$arg"; done | sort | uniq)

                  exit "$status"
                ' --
              '';
              stages = [ "pre-commit" ];
            };
            tflint = {
              enable = true;
              stages = [ "pre-commit" ];
            };
            trim-trailing-whitespace = {
              enable = true;
              excludes = [ "^db/" ];
              stages = [ "pre-commit" ];
            };
            trufflehog = {
              enable = true;
              stages = [ "pre-commit" ];
            };

            rubocop = {
              enable = true;
              name = "rubocop";
              description = "Run RuboCop through Bundler on changed Ruby files";
              entry = ''
                bash -c '
                  changed_files=$(git diff --name-only --diff-filter=ACM --merge-base main | grep -E "\\.(rb|rake)$|^(Gemfile|Rakefile|config\\.ru)$" || true)

                  if [ -n "$changed_files" ]; then
                    bundle exec rubocop --autocorrect --force-exclusion $changed_files
                  fi
                '
              '';
              files = "\\.(rb|rake)$|^(Gemfile|Rakefile|config\\.ru)$";
              pass_filenames = false;
              stages = [ "pre-commit" ];
            };
          };
        };
        # These programs are for a Bubblewrap-owned /workspace. The guard is an
        # operating switch, not an isolation boundary. Never enter the developer hook.
        review-common = pkgs.writeShellScript "review-common" ''
          set -uo pipefail
          umask 077
          if [ "''${REVIEW_SANDBOX:-}" != 1 ] || [ "$PWD" != /workspace ] || [ "$(pwd -P)" != /workspace ]; then
            echo "Review runtime requires REVIEW_SANDBOX=1 and /workspace inside Bubblewrap" >&2
            exit 78
          fi
          export HOME=/workspace/.review/home
          export RAILS_ENV=test SERVICE=uk ENVIRONMENT=test
          export PGHOST=127.0.0.1 PGPORT=5432 PGUSER=postgres DB_USER=postgres
          export PGDATABASE=tariff_test PGDATA=/workspace/.review/postgres
          export REDIS_URL=redis://127.0.0.1:6379 SIDEKIQ_REDIS_URL=redis://127.0.0.1:6379
          export FRONTEND_REDIS_URL=redis://127.0.0.1:6379 ELASTICSEARCH_URL=http://127.0.0.1:9200
          export OPENSEARCH_HOST=127.0.0.1 OPENSEARCH_PORT=9200
          export PARALLEL_TEST_PROCESSORS=5 TEST_RETRIES=0 RUN_DRAFT_DOCS=false
          unset DATABASE_URL READER_DATABASE_URL DB_PASSWORD PGPASSWORD PGSERVICE PGSERVICEFILE
          unset TEST_ENV_NUMBER SPEC_OPTS RSPEC_OPTS BUNDLE_WITH BUNDLE_WITHOUT
          export AWS_REGION=eu-west-2 AWS_EC2_METADATA_DISABLED=true
          export AWS_CONFIG_FILE=/dev/null AWS_SHARED_CREDENTIALS_FILE=/dev/null
          unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_PROFILE AWS_DEFAULT_PROFILE
          export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
          export NIX_SSL_CERT_FILE="$SSL_CERT_FILE" TZDIR=${pkgs.tzdata}/share/zoneinfo
          export BUNDLE_IGNORE_CONFIG=1 BUNDLE_FROZEN=true BUNDLE_ALLOW_OFFLINE_INSTALL=true
          export BUNDLE_PATH=/workspace/.review/bundle BUNDLE_APP_CONFIG=/workspace/.review/bundle-config
          export BUNDLE_USER_HOME=/workspace/.review/bundle-user BUNDLE_CACHE_PATH=/workspace/.review/gem-archives
          GEM_HOME="$BUNDLE_PATH/ruby/$(${ruby}/bin/ruby -rrbconfig -e 'print RbConfig::CONFIG.fetch("ruby_version")')" || exit 78
          export GEM_HOME GEM_PATH="$GEM_HOME"
          export PATH="${ruby}/bin:$GEM_HOME/bin:$PATH"
          export BUNDLE_BUILD__PG="${builtins.concatStringsSep " " postgresqlBuildFlags}"
          export BUNDLE_BUILD__PSYCH="${builtins.concatStringsSep " " psychBuildFlags}"
          export BUNDLE_BUILD__ZLIB="${builtins.concatStringsSep " " zlibBuildFlags}"
          export CPATH=${pkgs.zlib.dev}/include LIBRARY_PATH=${pkgs.zlib.out}/lib
          export PRE_COMMIT_HOME=/workspace/.review/pre-commit
          export TF_CLI_CONFIG_FILE=/workspace/.review/terraform.rc CHECKPOINT_DISABLE=1 TF_IN_AUTOMATION=1
          export TF_PLUGIN_CACHE_DIR=/workspace/.review/terraform-plugins
          unset TF_DATA_DIR TF_CLI_ARGS TF_CLI_ARGS_init TF_CLI_ARGS_plan TF_CLI_ARGS_apply
          mkdir -p "$HOME" "$BUNDLE_APP_CONFIG" "$BUNDLE_USER_HOME" "$TF_PLUGIN_CACHE_DIR"

          review_init() {
            review_dir="/workspace/.review/$1/$(date -u +%Y%m%dT%H%M%S)-$$"
            mkdir -p "$review_dir"
            ln -sfn "$(basename "$review_dir")" "/workspace/.review/$1/latest"
            printf 'check\texit\n' > "$review_dir/outcomes.tsv"
            review_failed=0
            review_unavailable=0
          }
          review_record() {
            printf '%s\t%s\n' "$1" "$2" >> "$review_dir/outcomes.tsv"
            printf '%s: exit %s (evidence: %s)\n' "$1" "$2" "$review_dir"
            case "$2" in
              0) ;;
              78) review_unavailable=1 ;;
              *) review_failed=1 ;;
            esac
          }
          review_run() {
            local label="$1" status
            shift
            if "$@" > "$review_dir/$label.log" 2>&1; then status=0; else status=$?; fi
            review_record "$label" "$status"
            return "$status"
          }
          review_finish() {
            local status=0
            if [ "$review_failed" != 0 ]; then status=1
            elif [ "$review_unavailable" != 0 ]; then status=78; fi
            printf '%s\n' "$status" > "$review_dir/exit-code"
            exit "$status"
          }
          review_binding() {
            sha256sum .ruby-version Gemfile Gemfile.lock
          }
          review_require_bundle() {
            bundle check || return 78
          }
          review_require_app() {
            [ -f /workspace/.review/bootstrap.binding ] || return 78
            review_binding | cmp -s /workspace/.review/bootstrap.binding - || return 78
            review_require_bundle || return 78
            pg_isready -h "$PGHOST" -p "$PGPORT" -U postgres || return 78
            [ "$(redis-cli -h 127.0.0.1 -p 6379 ping)" = PONG ] || return 78
            curl --fail --silent --max-time 5 "$ELASTICSEARCH_URL" >/dev/null || return 78
          }
          review_terraform_init() {
            local root="$1" inputs="/deps/terraform-inputs/roots/$1"
            [ -s "$inputs/lock.hcl" ] || { echo "Missing Terraform root cache: $root"; return 78; }
            [ -d /deps/terraform-inputs/providers ] || return 78
            if git ls-files --error-unmatch "$root/.terraform.lock.hcl" >/dev/null 2>&1; then
              cmp -s "$inputs/lock.hcl" "$root/.terraform.lock.hcl" || {
                echo "Tracked Terraform lock does not match inputs: $root"; return 78;
              }
            else
              cp "$inputs/lock.hcl" "$root/.terraform.lock.hcl" || return 78
            fi
            mkdir -p "$root/.terraform/modules"
            if [ -f "$inputs/modules.json" ]; then
              cp "$inputs/modules.json" "$root/.terraform/modules/modules.json" || return 78
            fi
            cat > "$TF_CLI_CONFIG_FILE" <<'TERRAFORM_RC'
          disable_checkpoint = true
          provider_installation {
            filesystem_mirror {
              path = "/deps/terraform-inputs/providers"
              include = ["registry.terraform.io/*/*"]
            }
          }
          TERRAFORM_RC
            # No direct installation fallback, backend, upgrade, or mutable tracked lock.
            terraform -chdir="$root" init -backend=false -input=false -lockfile=readonly -no-color
          }
        '';

        review-bootstrap = pkgs.writeShellScriptBin "review-bootstrap" ''
          source ${review-common}
          review_init bootstrap
          rm -f /workspace/.review/bootstrap.binding
          install_bundle() {
            [ "$(ruby -e 'print RUBY_VERSION')" = "$(tr -d '\n' < .ruby-version)" ] || return 78
            [ -d /deps/gem-archives ] || { echo "Missing /deps/gem-archives"; return 78; }
            mkdir -p "$GEM_HOME" "$BUNDLE_CACHE_PATH"
            chmod -R u+w "$GEM_HOME" "$BUNDLE_CACHE_PATH" || return 78
            local cache
            local -a caches
            IFS=: read -r -a caches <<< "''${REVIEW_GEM_CACHE:-}"
            for cache in "''${caches[@]}"; do
              [ -n "$cache" ] || continue
              case "$cache" in /deps/ruby-cache-*) ;; *) return 78 ;; esac
              [ -d "$cache" ] || return 78
              cp -R --no-preserve=ownership "$cache/." "$GEM_HOME/" || return 78
              chmod -R u+w "$GEM_HOME" || return 78
            done
            cp -R --no-preserve=ownership /deps/gem-archives/. "$BUNDLE_CACHE_PATH/" || return 78
            chmod -R u+w "$GEM_HOME" "$BUNDLE_CACHE_PATH"
            # Bundler enforces the current Gemfile.lock, including its Git revision.
            # --local must never fall back to fetching gems or Git sources.
            bundle install --local --jobs=4 --retry=0 || return 78
            bundle check || return 78
          }
          start_postgres() {
            mkdir -p "$PGDATA" /workspace/.review/pgsocket
            if [ ! -f "$PGDATA/PG_VERSION" ]; then
              initdb -D "$PGDATA" --username=postgres --auth=trust --encoding=UTF8 --no-locale || return 1
            fi
            if ! pg_isready -h 127.0.0.1 -p 5432 -U postgres; then
              pg_ctl start -D "$PGDATA" -l "$review_dir/postgres.log" \
                -o "-h 127.0.0.1 -p 5432 -k /workspace/.review/pgsocket -c log_min_messages=fatal" -w -t 60 || return 1
            fi
            pg_isready -h 127.0.0.1 -p 5432 -U postgres || return 1
            # Prove this is our private cluster before any database drop task.
            [ "$(psql -XAt -d postgres -c 'SHOW data_directory')" = "$PGDATA" ] || return 1
            if ! psql -XAt -d postgres -c "SELECT 1 FROM pg_database WHERE datname='tariff_test'" | grep -qx 1; then
              createdb tariff_test || return 1
            fi
          }
          start_redis() {
            mkdir -p /workspace/.review/redis
            if ! redis-cli -h 127.0.0.1 -p 6379 ping; then
              redis-server --bind 127.0.0.1 --port 6379 --dir /workspace/.review/redis \
                --save "" --appendonly no --daemonize yes --pidfile /workspace/.review/redis.pid \
                --logfile "$review_dir/redis.log" || return 1
            fi
            for _ in {1..60}; do
              [ "$(redis-cli -h 127.0.0.1 -p 6379 ping)" = PONG ] && return 0
              sleep 1
            done
            return 1
          }
          start_opensearch() {
            # Reuse the developer launcher, but keep its GC and service logs in evidence.
            mkdir -p /workspace/.nix /workspace/.review/opensearch
            if [ -e /workspace/.nix/opensearch ] && [ ! -L /workspace/.nix/opensearch ]; then
              echo "OpenSearch runtime path is not the review-owned symlink"
              return 78
            fi
            ln -sfn /workspace/.review/opensearch /workspace/.nix/opensearch
            if ! curl --fail --silent --max-time 2 "$ELASTICSEARCH_URL" >/dev/null; then
              ${opensearch-start}/bin/opensearch-start > "$review_dir/opensearch.log" 2>&1 < /dev/null &
              echo "$!" > /workspace/.review/opensearch.pid
            fi
            for _ in {1..180}; do
              if curl --fail --silent --max-time 2 \
                "$ELASTICSEARCH_URL/_cluster/health?wait_for_status=yellow&timeout=1s" \
                > "$review_dir/opensearch-health.json"; then
                ruby -rjson -e 'h=JSON.parse(File.read(ARGV[0])); exit(!h["timed_out"] && %w[green yellow].include?(h["status"]) ? 0 : 1)' \
                  "$review_dir/opensearch-health.json" && return 0
              fi
              sleep 1
            done
            return 1
          }
          review_run bundle install_bundle || review_finish
          review_run postgres start_postgres || review_finish
          review_run redis start_redis || review_finish
          review_run opensearch start_opensearch || review_finish
          # RAILS_ENV, SERVICE, DB_USER and all endpoints are fixed by review-common
          # before Rails loads .env files or the destructive five-worker preparation.
          review_run prepare bundle exec rails db:test:prepare_parallel || review_finish
          review_run identity bundle exec rails runner '
            abort "wrong Rails environment" unless Rails.env.test? && ENV.fetch("SERVICE") == "uk"
            db = Sequel::Model.db
            abort "wrong database" unless db.get(Sequel.lit("current_database()")) == "tariff_test"
            abort "wrong cluster" unless db.get(Sequel.lit("current_setting(?)", "data_directory")) == ENV.fetch("PGDATA")
            abort "wrong schema" unless db.get(Sequel.lit("current_schema()")) == "uk"
            abort "Redis unavailable" unless TradeTariffBackend.redis.ping == "PONG"
            puts "Rails #{Rails.version}: test/uk, private tariff_test, Redis PONG"
          ' || review_finish
          if ! review_binding > /workspace/.review/bootstrap.binding; then
            rm -f /workspace/.review/bootstrap.binding
            review_record binding 1
          fi
          review_finish
        '';

        review-unit = pkgs.writeShellScriptBin "review-unit" ''
          source ${review-common}
          review_init unit
          review_run prerequisites review_require_app || review_finish
          mkdir -p "$review_dir/ctrf"
          export REVIEW_CTRF_DIR="$review_dir/ctrf"
          printf 'FLAKY_TAGS=included\nUPSTREAM_DRAFT_DOCS=excluded (spec/spec_helper.rb)\n' > "$review_dir/scope.txt"
          review_run rspec bundle exec parallel_test spec -n "$PARALLEL_TEST_PROCESSORS" --type rspec \
            --exec-args "sh -c 'PARALLEL_RSPEC_CHILD=true bundle exec rspec \"\$@\" --options /dev/null --require ./spec/parallel_rspec --require rails_helper --format progress --format Ctrf::RSpecFormatter --out $REVIEW_CTRF_DIR/ctrf\''${TEST_ENV_NUMBER:-1}.json' sh" || true
          review_run summary ruby -rjson -e '
            expected = %w[1 2 3 4 5].map { |n| "ctrf#{n}.json" }
            files = Dir[File.join(ENV.fetch("REVIEW_CTRF_DIR"), "ctrf*.json")]
            totals = %w[tests passed failed pending skipped other].to_h { |key| [key, 0] }
            invalid = []
            files.each do |file|
              begin
                summary = JSON.parse(File.read(file)).fetch("results").fetch("summary")
                counts = %w[tests passed failed pending skipped other].to_h { |key| [key, summary.fetch(key)] }
                raise "invalid count" unless counts.values.all? { |value| value.is_a?(Integer) && value >= 0 }
                raise "inconsistent counts" unless counts.fetch("tests") == counts.except("tests").values.sum
                counts.each { |key, value| totals[key] += value }
              rescue StandardError
                invalid << File.basename(file)
              end
            end
            missing = expected - files.map { |f| File.basename(f) }
            totals["missing_workers"] = missing.length
            totals["invalid_workers"] = invalid.length
            totals["unexpected_workers"] = (files.map { |f| File.basename(f) } - expected).length
            result = { "totals" => totals, "missing" => missing, "invalid" => invalid }
            File.write(File.join(ENV.fetch("REVIEW_CTRF_DIR"), "summary.json"), JSON.pretty_generate(result))
            puts "FULL_SUITE_SUMMARY=" + JSON.generate(result)
            exit(totals["tests"] > 0 && totals["passed"] == totals["tests"] &&
              totals.values_at("failed", "pending", "skipped", "other", "missing_workers", "invalid_workers", "unexpected_workers").all?(&:zero?) ? 0 : 1)
          ' || true
          review_finish
        '';

        # Native equivalents of the upstream Terraform per-directory hooks. The
        # filename selection lives in review-lint-config, not in changed-file Git probes.
        review-terraform-hook = pkgs.writeShellScriptBin "review-terraform-hook" ''
          source ${review-common}
          mode="$1"
          shift
          review_init "terraform-$mode"
          mapfile -t roots < <(for file in "$@"; do dirname "$file"; done | sort -u)
          for root in "''${roots[@]}"; do
            label=$(printf '%s' "$root" | tr '/.' '__')
            case "$mode" in
              fmt) review_run "$label-fmt" terraform -chdir="$root" fmt || true ;;
              validate)
                if review_run "$label-init" review_terraform_init "$root"; then
                  review_run "$label-validate" terraform -chdir="$root" validate -no-color || true
                fi
                ;;
              tflint)
                if review_run "$label-tflint-init" tflint --chdir="$root" --init; then
                  review_run "$label-tflint" tflint --chdir="$root" || true
                fi
                ;;
              docs)
                # --add-to-existing-file and --create-file-if-not-exist are true
                # upstream. Keep writes private and let pre-commit detect mutations.
                if [ ! -f "$root/README.md" ]; then
                  printf '# %s\n\n<!-- BEGIN_TF_DOCS -->\n<!-- END_TF_DOCS -->\n' "$(basename "$root")" > "$root/README.md"
                fi
                review_run "$label-docs" terraform-docs markdown table --output-file README.md --output-mode inject "$root" || true
                ;;
              *) review_record unknown-mode 1 ;;
            esac
          done
          if [ -n "''${REVIEW_TERRAFORM_STATUS:-}" ]; then
            if [ "$review_failed" != 0 ]; then echo 1
            elif [ "$review_unavailable" != 0 ]; then echo 78
            else echo 0; fi >> "$REVIEW_TERRAFORM_STATUS"
          fi
          review_finish
        '';

        review-terraform = pkgs.writeShellScriptBin "review-terraform" ''
          source ${review-common}
          review_init terraform
          review_run version terraform version || true
          mapfile -t roots < <(git ls-files '*.tf' | while IFS= read -r file; do dirname "$file"; done | sort -u)
          [ "''${#roots[@]}" -gt 0 ] || review_record missing-roots 78
          for root in "''${roots[@]}"; do
            label=$(printf '%s' "$root" | tr '/.' '__')
            review_run "$label-fmt" terraform -chdir="$root" fmt -check || true
            if review_run "$label-init" review_terraform_init "$root"; then
              review_run "$label-validate" terraform -chdir="$root" validate -no-color || true
            fi
          done
          for module in puma_capacity_dashboard search_dashboard search_operations_dashboard search_quality_dashboard; do
            root="terraform/modules/$module"
            # Only the four CI mock-provider plan files, never a live plan or apply.
            test_file="$root/tests/dashboard.tftest.hcl"
            if [ ! -f "$test_file" ] || ! grep -Eq '^mock_provider "aws" *\{\}' "$test_file" \
              || ! grep -Eq '^run "' "$test_file" \
              || [ "$(grep -cE '^run "' "$test_file")" != "$(grep -cE '^ *command *= *plan *$' "$test_file")" ] \
              || grep -Eq 'command *= *apply' "$test_file"; then
              review_record "$module-mock-test-prerequisites" 78
              continue
            fi
            if review_run "$module-init" review_terraform_init "$root"; then
              review_run "$module-tests" terraform -chdir="$root" test -filter=tests/dashboard.tftest.hcl -no-color || true
            fi
          done
          review_finish
        '';

        review-trufflehog = pkgs.writeShellScriptBin "review-trufflehog" ''
          source ${review-common}
          review_init trufflehog
          trufflehog git file://. --since-commit HEAD --results=verified --fail --trust-local-git-config --json \
            > "$review_dir/findings.jsonl" 2> "$review_dir/stderr.log"
          status=$?
          printf '%s\n' "$status" > "$review_dir/scanner-exit-code"
          if [ "$status" = 183 ]; then
            review_record verified-secrets 1
          elif [ "$status" != 0 ]; then
            review_record scanner-failure "$status"
          else
            # Verification requires provider network access. A zero scanner exit in
            # an offline namespace is not evidence that verified-only scanning passed.
            printf 'Verified-only secret verification is unavailable offline; scanner exit %s. Raw evidence remains private.\n' "$status" \
              > "$review_dir/limitation.txt"
            review_record offline-verification 78
          fi
          review_finish
        '';

        review-lint-config = pkgs.writeText "review-lint.yaml" ''
          default_stages: [pre-commit]
          repos:
            - repo: local
              hooks:
                - id: terraform_fmt
                  name: Terraform fmt
                  entry: review-terraform-hook fmt
                  language: system
                  require_serial: true
                  files: \.(tf|tofu|tfvars|(tftest|tofutest|tfmock|tfquery)\.hcl)$
                  exclude: \.terraform/.*$
                - id: terraform_validate
                  name: Terraform validate (offline)
                  entry: review-terraform-hook validate
                  language: system
                  require_serial: true
                  files: \.(tf|tofu|tfvars|terraform\.lock\.hcl)$
                  exclude: \.terraform/.*$
                - id: terraform_tflint
                  name: Terraform TFLint
                  entry: review-terraform-hook tflint
                  language: system
                  require_serial: true
                  files: \.(tf|tofu|tfvars)$
                  exclude: \.terraform/.*$
                - id: terraform_docs
                  name: Terraform docs (add to existing, create if absent)
                  entry: review-terraform-hook docs
                  language: system
                  require_serial: true
                  files: \.(tf|tofu|terraform\.lock\.hcl)$
                  exclude: \.terraform/.*$
                - id: trailing-whitespace
                  name: trailing whitespace
                  entry: trailing-whitespace-fixer
                  language: system
                  types: [text]
                  exclude: ^db/
                - id: end-of-file-fixer
                  name: end of file
                  entry: end-of-file-fixer
                  language: system
                  types: [text]
                  exclude: ^db/|config/credentials.yml.enc
                - id: check-yaml
                  name: YAML syntax
                  entry: check-yaml
                  language: system
                  types: [yaml]
                  exclude: ^db/|config/sidekiq.yml
                - id: file-contents-sorter
                  name: environment sorting
                  entry: file-contents-sorter
                  language: system
                  files: .env.development|.env.test
                - id: shellcheck
                  name: ShellCheck
                  entry: shellcheck --severity=warning
                  language: system
                  types: [shell]
                - id: trufflehog
                  name: TruffleHog (verified-only, offline limitation)
                  entry: review-trufflehog
                  language: system
                  pass_filenames: false
                - id: rubocop
                  name: RuboCop
                  entry: bundle exec rubocop --force-exclusion --color --autocorrect
                  language: system
                  types: [ruby]
                - id: actionlint-docker
                  name: actionlint (native, no Docker)
                  entry: actionlint
                  language: system
                  types: [yaml]
                  files: ^\.github/workflows/
        '';

        review-lint = pkgs.writeShellScriptBin "review-lint" ''
          source ${review-common}
          review_init lint
          snapshot() {
            git ls-files -z --cached --others --exclude-standard -- . ':!.review/**' ':!.nix/**' \
              | sort -zu | xargs -0 -r sha256sum
          }
          local_hook() {
            local hook="$1" status
            export REVIEW_TERRAFORM_STATUS="$review_dir/$hook.status"
            pre-commit run "$hook" --config ${review-lint-config} --all-files --hook-stage pre-commit
            status=$?
            # pre-commit maps a hook exit 78 to 1. Recover prerequisites-unavailable
            # only if every nonzero Terraform hook result was 78, not a real failure.
            if [ "$status" != 0 ] && [ -s "$REVIEW_TERRAFORM_STATUS" ] \
              && grep -qx 78 "$REVIEW_TERRAFORM_STATUS" \
              && ! grep -Evq '^(0|78)$' "$REVIEW_TERRAFORM_STATUS"; then return 78; fi
            return "$status"
          }
          snapshot > "$review_dir/source-before.sha256" || review_record source-before 1
          for hook in terraform_fmt terraform_validate terraform_tflint terraform_docs \
            trailing-whitespace end-of-file-fixer check-yaml file-contents-sorter shellcheck rubocop actionlint-docker; do
            if [ "$hook" = rubocop ] && ! review_require_bundle > "$review_dir/rubocop-prerequisites.log" 2>&1; then
              review_record rubocop 78
              continue
            fi
            review_run "$hook" local_hook "$hook" || true
          done
          # Run independently so pre-commit cannot turn an offline limitation into
          # a claimed pass or obscure the remaining hooks and standalone Brakeman.
          review_run trufflehog ${review-trufflehog}/bin/review-trufflehog || true
          if review_run brakeman-prerequisites review_require_bundle; then
            review_run brakeman bundle exec brakeman --no-pager || true
          fi
          snapshot > "$review_dir/source-after.sha256" || review_record source-after 1
          review_run mutation-detection cmp "$review_dir/source-before.sha256" "$review_dir/source-after.sha256" || true
          git diff --binary > "$review_dir/mutations.patch" || review_record mutation-patch 1
          review_finish
        '';

        review-swagger = pkgs.writeShellScriptBin "review-swagger" ''
          source ${review-common}
          review_init swagger
          review_run prerequisites review_require_app || review_finish
          review_run coverage bundle exec rake swagger:check_coverage || true
          # Remove the old document so a no-op generation cannot validate stale output.
          rm -f swagger/v2/swagger.json
          review_run generate bundle exec rake swagger:generate || true
          review_run document ruby -rjson -e '
            path = "swagger/v2/swagger.json"
            abort "Missing generated OpenAPI document" unless File.file?(path) && File.size(path) > 0
            doc = JSON.parse(File.read(path))
            abort "Invalid OpenAPI document" unless doc.fetch("openapi").start_with?("3.") && !doc.fetch("paths").empty?
            puts "GENERATED_OPENAPI_PATHS=#{doc.fetch("paths").length}"
          ' || true
          git diff --binary -- swagger/v2/swagger.json > "$review_dir/generated.patch"
          review_finish
        '';

        review-check = pkgs.writeShellScriptBin "review-check" ''
          source ${review-common}
          review_init check
          # A failed bootstrap or check is evidence. Continue all independent groups.
          review_run bootstrap ${review-bootstrap}/bin/review-bootstrap || true
          review_run unit ${review-unit}/bin/review-unit || true
          review_run terraform ${review-terraform}/bin/review-terraform || true
          review_run lint ${review-lint}/bin/review-lint || true
          review_run swagger ${review-swagger}/bin/review-swagger || true
          review_finish
        '';
      in
      {
        devShells.review = pkgs.mkShell {
          # Intentionally no shellHook, inputsFrom default, pre-commit install, or AWS CLI.
          packages = [
            ruby
            postgresql
            pgConfig
            opensearch-start
            pkgs.redis
            pkgs.opensearch
            pkgs.terraform
            pkgs.tflint
            pkgs.terraform-docs
            pkgs.shellcheck
            pkgs.actionlint
            pkgs.trufflehog
            pkgs.pre-commit
            pkgs.python3Packages.pre-commit-hooks
            pkgs.git
            pkgs.bash
            pkgs.python3
            pkgs.gnutar
            pkgs.gzip
            pkgs.unzip
            pkgs.coreutils
            pkgs.findutils
            pkgs.diffutils
            pkgs.gnugrep
            pkgs.gnused
            pkgs.gawk
            pkgs.curl
            pkgs.pkg-config
            pkgs.gnumake
            pkgs.stdenv.cc
            pkgs.libyaml
            pkgs.zlib
            pkgs.cacert
            pkgs.tzdata
            review-bootstrap
            review-unit
            review-terraform-hook
            review-terraform
            review-trufflehog
            review-lint
            review-swagger
            review-check
          ];
          SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
          NIX_SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
          TZDIR = "${pkgs.tzdata}/share/zoneinfo";
          BUNDLE_BUILD__PG = builtins.concatStringsSep " " postgresqlBuildFlags;
          BUNDLE_BUILD__PSYCH = builtins.concatStringsSep " " psychBuildFlags;
          BUNDLE_BUILD__ZLIB = builtins.concatStringsSep " " zlibBuildFlags;
          CPATH = "${pkgs.zlib.dev}/include";
          LIBRARY_PATH = "${pkgs.zlib.out}/lib";
        };

        devShells.default = pkgs.mkShell {
          shellHook = ''
            # For misbehaving gems that don't pick up the flags from BUNDLE_BUILD_*
            export CPATH="${pkgs.zlib.dev}/include:$CPATH"
            export LIBRARY_PATH="${pkgs.zlib.out}/lib:$LIBRARY_PATH"

            # Worktree-aware Bundler/Ruby isolation
            if [ "$(${worktree.isWorktree})" = "true" ]; then
              WT_ID=$(${worktree.id})
              WT_ROOT=$(git -c core.fsmonitor=false rev-parse --show-toplevel)
              WT_BUNDLE_PATH="$WT_ROOT/.bundle"
              export GEM_HOME="$HOME/.local/share/gem/worktrees/$WT_ID"
              export BUNDLE_PATH="$WT_BUNDLE_PATH"
              export BUNDLE_APP_CONFIG="$WT_BUNDLE_PATH"
              export BUNDLE_IGNORE_CONFIG=1
              mkdir -p "$GEM_HOME" "$WT_BUNDLE_PATH"
              echo "Worktree Bundler isolation enabled (ID: $WT_ID)"
            else
              export GEM_HOME=$PWD/.nix/ruby/$(${ruby}/bin/ruby -e "puts RUBY_VERSION")
              mkdir -p $GEM_HOME
            fi

            export BUNDLE_BUILD__PG="${builtins.concatStringsSep " " postgresqlBuildFlags}"
            export BUNDLE_BUILD__PSYCH="${builtins.concatStringsSep " " psychBuildFlags}"
            export BUNDLE_BUILD__ZLIB="${builtins.concatStringsSep " " zlibBuildFlags}"

            export GEM_PATH=$GEM_HOME
            export PATH=${ruby}/bin:$GEM_HOME/bin:$PATH

            ${pg-environment-variables}

            ${worktree-info}/bin/worktree-info

            # === Automatic per-worktree database initialization ===
            if [ "$(${worktree.isWorktree})" = "true" ]; then
              WT_ID=$(${worktree.id})
              MARKER="$PGDATA/.worktree-initialized"
              PIDFILE="/tmp/pg-$WT_ID.pid"

              if [ ! -f "$MARKER" ]; then
                echo ""
                echo "==> First time in this worktree ($WT_ID) - running full setup..."
                echo ""

                fail_worktree_setup() {
                  echo ""
                  echo "==> Worktree setup failed. Fix the error above, then re-enter the shell."
                  if [ -f "$PGDATA/postmaster.pid" ]; then
                    ${postgresql}/bin/pg_ctl stop -D "$PGDATA" -s -m fast || true
                  fi
                  exit 1
                }

                run_setup_step() {
                  label="$1"
                  shift
                  log_file="/tmp/worktree-$WT_ID-$(echo "$label" | tr '[:upper:] /:' '[:lower:]---').log"

                  echo "    $label..."
                  # Setup commands may spawn daemon helpers, such as git fsmonitor. Close
                  # inherited nix-direnv pipe fds so those helpers cannot block `direnv exec`.
                  if "$@" >"$log_file" 2>&1 \
                    3>&- 4>&- 5>&- \
                    6>&- 7>&- 8>&- 9>&-; then
                    echo "      ok (log: $log_file)"
                  else
                    status=$?
                    echo "      failed with exit $status (log: $log_file)"
                    echo "      last 80 log lines:"
                    tail -80 "$log_file" | sed 's/^/        /'
                    return "$status"
                  fi
                }

                # Start Postgres as a proper daemon on the short socket (backend tuning)
                if ! ${postgresql}/bin/pg_isready -h "$PGHOST" -p "''${PGPORT:-5432}" >/dev/null 2>&1; then
                  echo "    Starting Postgres as daemon on short socket..."
                  if [ ! -f "$PGDATA/PG_VERSION" ]; then
                    mkdir -p "$PGDATA"
                    run_setup_step "Initialising Postgres data directory" ${postgresql}/bin/initdb "$PGDATA" --auth=trust || fail_worktree_setup
                  fi
                  rm -f "$PIDFILE"
                  # pg_ctl daemonises Postgres from inside direnv's shellHook. File descriptors
                  # 3+ are extra handles opened by the parent process; `>&-` closes them for this
                  # command. Without this, Postgres inherits a nix-direnv pipe and the first
                  # `direnv exec ...` stays blocked after setup instead of running its command.
                  if ! ${postgresql}/bin/pg_ctl start \
                    -D "$PGDATA" \
                    -l "/tmp/pg-$WT_ID.log" \
                    -o "-k $PGHOST -c listen_addresses= -c max_wal_size=16GB -c maintenance_work_mem=8GB -c external_pid_file=$PIDFILE" \
                    -w \
                    -t 60 \
                    3>&- 4>&- 5>&- \
                    6>&- 7>&- 8>&- 9>&-; then
                    echo "      failed to start Postgres (log: /tmp/pg-$WT_ID.log)"
                    echo "      last 80 log lines:"
                    tail -80 "/tmp/pg-$WT_ID.log" | sed 's/^/        /' || true
                    fail_worktree_setup
                  fi
                  for i in {1..60}; do
                    if ${postgresql}/bin/pg_isready -h "$PGHOST" -p "''${PGPORT:-5432}" >/dev/null 2>&1; then
                      break
                    fi
                    sleep 1
                  done
                  if ! ${postgresql}/bin/pg_isready -h "$PGHOST" -p "''${PGPORT:-5432}" >/tmp/pg-$WT_ID-ready.log 2>&1; then
                    echo "      Postgres did not become ready on $PGHOST"
                    cat /tmp/pg-$WT_ID-ready.log | sed 's/^/        /' || true
                    fail_worktree_setup
                  fi
                fi

                # Defensive bundle install (only on first entry)
                rm -rf "$BUNDLE_PATH"
                mkdir -p "$BUNDLE_PATH"
                export BUNDLE_IGNORE_CONFIG=1
                run_setup_step "Installing gems" bundle install --jobs=4 --retry=3 || fail_worktree_setup

                # Database preparation (this app exposes Sequel-backed db tasks, not db:prepare)
                run_setup_step "Creating development database" bundle exec rails db:create || fail_worktree_setup
                run_setup_step "Loading development structure" bundle exec rails db:structure:load || fail_worktree_setup
                run_setup_step "Creating test database" env RAILS_ENV=test bundle exec rails db:create || fail_worktree_setup
                run_setup_step "Loading test structure" env RAILS_ENV=test bundle exec rails db:structure:load || fail_worktree_setup
                touch "$MARKER"
                echo ""
                echo "==> Worktree first-time setup complete."
                echo ""
              else
                # Marked worktree — just ensure env vars are set
                export BUNDLE_IGNORE_CONFIG=1
              fi
            fi

            ${preCommitCheck.shellHook}
            export PATH=${pkgs.writeShellScriptBin "pre-commit" ''
              set -euo pipefail

              has_config=false
              for arg in "$@"; do
                case "$arg" in
                  -c|--config|--config=*)
                    has_config=true
                    ;;
                esac
              done

              if [ "$has_config" = true ]; then
                exec ${preCommitCheck.config.package}/bin/pre-commit "$@"
              fi

              if [ "''${1:-}" = "run" ]; then
                shift
                exec ${preCommitCheck.config.package}/bin/pre-commit run --config .pre-commit-config-nix.yaml "$@"
              fi

              exec ${preCommitCheck.config.package}/bin/pre-commit "$@"
            ''}/bin:$PATH
          '';

          buildInputs = preCommitCheck.enabledPackages ++ [
            init
            lint
            pkgs.pkg-config
            pkgs.python3
            pkgs.opensearch
            pkgs.redis
            pkgs.socat
            pkgs.terraform-docs
            pkgs.zlib
            opensearch-start
            postgresql
            pgConfig
            postgresql-start
            redis-start
            ruby
            update-providers
            worktree-info
            worktree-clean
          ];
        };
      }
    );
}
