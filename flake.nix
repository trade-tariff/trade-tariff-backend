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
        worktree = rec {
          isWorktree = ''
            if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
              if [ "$(git rev-parse --git-dir 2>/dev/null)" != "$(git rev-parse --git-common-dir 2>/dev/null)" ]; then
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
              git rev-parse --show-toplevel | md5sum | cut -c1-8
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

          if [ ! -d $PGDATA ]; then
            mkdir -p $PGDATA
            ${postgresql}/bin/initdb $PGDATA --auth=trust
          fi

          ${postgresql}/bin/postgres \
            -k $PGHOST \
            -c listen_addresses=''' \
            -c unix_socket_directories=$PGHOST \
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

          # Drop the standard databases (isolation comes from PGHOST)
          if command -v dropdb >/dev/null 2>&1; then
            dropdb --if-exists "tariff_development" || true
            dropdb --if-exists "tariff_test" || true
          fi

          # Remove short socket dir and per-worktree Postgres data
          rm -rf "/tmp/pg-$WT_ID"
          rm -rf "$HOME/.local/share/postgres/worktrees/$WT_ID"

          # Remove per-worktree Bundler state
          rm -rf ".bundle"
          rm -rf "$HOME/.local/share/gem/worktrees/$WT_ID" 2>/dev/null || true
          rm -rf "$HOME/.cache/bundle/worktrees/$WT_ID" 2>/dev/null || true

          # Remove marker
          rm -f "$HOME/.local/share/postgres/worktrees/$WT_ID/.worktree-initialized" 2>/dev/null || true

          echo "Worktree $WT_ID cleaned (Postgres + bundle)."
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
              export GEM_HOME="$HOME/.local/share/gem/worktrees/$WT_ID"
              export BUNDLE_PATH=".bundle"
              export BUNDLE_APP_CONFIG=".bundle"
              export BUNDLE_IGNORE_CONFIG=1
              export BUNDLE_FORCE_RUBY_PLATFORM=1
              mkdir -p "$GEM_HOME" ".bundle"
              echo "Worktree Bundler isolation enabled (ID: $WT_ID)"
            else
              export GEM_HOME=$PWD/.nix/ruby/$(${ruby}/bin/ruby -e "puts RUBY_VERSION")
              mkdir -p $GEM_HOME
            fi

            export BUNDLE_BUILD__PG="${builtins.concatStringsSep " " postgresqlBuildFlags}"
            export BUNDLE_BUILD__PSYCH="${builtins.concatStringsSep " " psychBuildFlags}"
            export BUNDLE_BUILD__ZLIB="${builtins.concatStringsSep " " zlibBuildFlags}"

            export GEM_PATH=$GEM_HOME
            export PATH=$GEM_HOME/bin:$PATH

            ${pg-environment-variables}

            ${worktree-info}/bin/worktree-info

            # Ensure pre-commit hooks are installed (so they actually run on commit)
            if command -v pre-commit >/dev/null 2>&1; then
              pre-commit install --install-hooks 2>/dev/null || true
            fi

            # === Automatic per-worktree database initialization ===
            if [ "$(${worktree.isWorktree})" = "true" ]; then
              WT_ID=$(${worktree.id})
              MARKER="$PGDATA/.worktree-initialized"

              if [ ! -f "$MARKER" ]; then
                echo ""
                echo "==> First time in this worktree (ID: $WT_ID)"
                echo "    Installing gems + initializing databases + assets..."
                echo ""

                # Start Postgres as a proper daemon on the short socket (backend-specific tuning)
                if ! pg_isready -h "$PGHOST" -p "${PGPORT:-5432}" >/dev/null 2>&1; then
                  echo "    Starting Postgres as daemon on short socket..."
                  pg_ctl start -D "$PGDATA" -l "/tmp/pg-$WT_ID.log" \
                    -o "-k $PGHOST -c listen_addresses='' -c max_wal_size=16GB -c maintenance_work_mem=8GB" \
                    -w -t 30 || true
                fi

                rm -rf .bundle
                bundle install --jobs=4 --retry=3 2>&1 | tail -8 || true
                bundle exec rails db:create 2>&1 | tail -3 || true
                bundle exec rails db:structure:load 2>&1 | tail -5 || true

                echo ""
                echo "    Preparing test database..."
                RAILS_ENV=test bundle exec rails db:test:prepare 2>&1 | tail -5 || true

                touch "$MARKER"
                echo ""
                echo "==> Worktree databases ready."
                echo ""
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
