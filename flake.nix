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

  outputs = { self, nixpkgs, flake-utils, nixpkgs-ruby }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          system = system;
          overlays = [ nixpkgs-ruby.overlays.default ];
        };

        rubyVersion = builtins.head (builtins.split "\n" (builtins.readFile ./.ruby-version));
        ruby = pkgs."ruby-${rubyVersion}";

        postgresqlBuildFlags = with pkgs; [
          "--with-pg-config=${lib.getDev postgresql_16}/bin/pg_config"
        ];
        psychBuildFlags = with pkgs; [
          "--with-libyaml-include=${libyaml.dev}/include"
          "--with-libyaml-lib=${libyaml.out}/lib"
        ];
        postgresql = pkgs.postgresql_16.withPackages (p: [ p.postgis ]);
        pg-environment-variables = ''
          export PGDATA=$PWD/.nix/postgres/data
          export PGHOST=$PWD/.nix/postgres
          export DB_USER=""
        '';

        postgresql-start = pkgs.writeScriptBin "pg-start" ''
          ${pg-environment-variables}

          if [ ! -d $PGDATA ]; then
            mkdir -p $PGDATA

            ${postgresql}/bin/initdb $PGDATA --auth=trust
          fi

          ${postgresql}/bin/postgres -k $PGHOST -c listen_addresses=''' -c unix_socket_directories=$PGHOST
        '';

        lint = pkgs.writeScriptBin "lint" ''
          changed_files=$(git diff --name-only --diff-filter=ACM --merge-base main)

          bundle exec rubocop --autocorrect-all --force-exclusion $changed_files Gemfile
        '';

        update-providers = pkgs.writeScriptBin "update-providers" ''
          cd terraform
          terraform init -backend=false -reconfigure -upgrade
        '';
      in
      {
        devShells.default = pkgs.mkShell {
          shellHook = ''
            export GEM_HOME=$PWD/.nix/ruby/$(${ruby}/bin/ruby -e "puts RUBY_VERSION")
            mkdir -p $GEM_HOME

            export BUNDLE_BUILD__PG="${
              builtins.concatStringsSep " " postgresqlBuildFlags
            }"

            export BUNDLE_BUILD__PSYCH="${
              builtins.concatStringsSep " " psychBuildFlags
            }"

            export GEM_PATH=$GEM_HOME
            export PATH=$GEM_HOME/bin:$PATH

            ${pg-environment-variables}
          '';

          buildInputs = [
            lint
            pkgs.circleci-cli
            postgresql
            postgresql-start
            ruby
            update-providers
          ];
        };
      });
}
