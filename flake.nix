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
        pg-environment-variables = ''
          export PGDATA=$PWD/.nix/postgres/data
          export PGHOST=$PWD/.nix/postgres
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

            export GEM_HOME=$PWD/.nix/ruby/$(${ruby}/bin/ruby -e "puts RUBY_VERSION")
            mkdir -p $GEM_HOME

            export BUNDLE_BUILD__PG="${builtins.concatStringsSep " " postgresqlBuildFlags}"

            export BUNDLE_BUILD__PSYCH="${builtins.concatStringsSep " " psychBuildFlags}"
            export BUNDLE_BUILD__ZLIB="${builtins.concatStringsSep " " zlibBuildFlags}"

            export GEM_PATH=$GEM_HOME
            export PATH=$GEM_HOME/bin:$PATH

            ${pg-environment-variables}
          '';

          buildInputs = [
            init
            lint
            pkgs.python3
            pkgs.opensearch
            pkgs.redis
            pkgs.socat
            pkgs.zlib
            opensearch-start
            postgresql
            postgresql-start
            redis-start
            ruby
            update-providers
          ];
        };
      }
    );
}
