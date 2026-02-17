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

          ${postgresql}/bin/postgres -k $PGHOST -c listen_addresses=''' -c unix_socket_directories=$PGHOST -c max_wal_size=16GB
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
            pkgs.socat
            pkgs.zlib
            postgresql
            postgresql-start
            ruby
            update-providers
          ];
        };
      }
    );
}
