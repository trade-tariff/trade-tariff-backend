{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs-ruby = {
      url = "github:bobvanderlinden/nixpkgs-ruby";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      nixpkgs-ruby,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          system = system;
          overlays = [ nixpkgs-ruby.overlays.default ];
        };

        rubyVersion = builtins.head (builtins.split "\n" (builtins.readFile ./.ruby-version));
        ruby = pkgs."ruby-${rubyVersion}";

        postgresqlBuildFlags = with pkgs; [
          "--with-pg-config=${lib.getDev postgresql.pg_config}/bin/pg_config"
        ];
        psychBuildFlags = with pkgs; [
          "--with-libyaml-include=${libyaml.dev}/include"
          "--with-libyaml-lib=${libyaml.out}/lib"
        ];
        zlibBuildFlags = with pkgs; [
          "--with-zlib-include=${zlib.dev}/include"
          "--with-zlib-lib=${zlib.out}/lib"
        ];
        postgresql = pkgs.postgresql_18.withPackages (ps: [ ps.pgvector ]);

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
          changed_files=$(git diff --name-only --diff-filter=ACM --merge-base main)

          bundle exec rubocop --autocorrect-all --force-exclusion $changed_files Gemfile
        '';

        init = pkgs.writeShellScriptBin "init" ''
          cd terraform && terraform init -input=false -no-color -backend=false
        '';

        update-providers = pkgs.writeShellScriptBin "update-providers" ''
          cd terraform
          terraform init -backend=false -reconfigure -upgrade
        '';
      in
      {
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

                # Pre-commit hooks (only on first entry after worktree add)
                run_setup_step "Installing pre-commit hooks" pre-commit install --install-hooks || fail_worktree_setup

                touch "$MARKER"
                echo ""
                echo "==> Worktree first-time setup complete."
                echo ""
              else
                # Marked worktree — just ensure env vars are set
                export BUNDLE_IGNORE_CONFIG=1
              fi
            fi
          '';

          buildInputs = [
            init
            lint
            pkgs.pre-commit
            pkgs.python3
            pkgs.opensearch
            pkgs.redis
            pkgs.socat
            pkgs.terraform-docs
            pkgs.zlib
            opensearch-start
            postgresql
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
