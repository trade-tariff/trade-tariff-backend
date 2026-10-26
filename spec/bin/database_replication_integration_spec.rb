# frozen_string_literal: true

require 'open3'
require 'securerandom'
require 'tmpdir'
require 'zlib'

RSpec.describe 'database replication with PostgreSQL' do
  attr_reader :backup_script,
              :command_log,
              :database_user,
              :dump_file,
              :pg_dump_container,
              :real_pg_dump,
              :real_psql,
              :replicate_script,
              :target_database,
              :tempdir

  def run_command(*command, stdin_data: '')
    stdout, stderr, status = Open3.capture3(*command, stdin_data:)
    raise "#{command.join(' ')} failed:\n#{stdout}\n#{stderr}" unless status.success?

    stdout
  end

  def psql(database, sql)
    run_command('psql', '-X', '--username', database_user, '-v', 'ON_ERROR_STOP=1', '-q', database, '-c', sql)
  end

  def query(database, sql)
    run_command('psql', '-X', '--username', database_user, '-Atq', database, '-c', sql).strip
  end

  def write_executable(name, contents)
    path = File.join(tempdir, 'bin', name)
    File.write(path, contents)
    File.chmod(0o755, path)
  end

  def create_target_database
    run_command('createdb', '--username', database_user, target_database)

    psql(target_database, <<~SQL)
      CREATE TABLE restore_probe(value text);
      INSERT INTO restore_probe VALUES ('old');
      CREATE MATERIALIZED VIEW restore_probe_view AS
        SELECT value FROM restore_probe;
      CREATE FUNCTION noop_event_trigger() RETURNS event_trigger
        LANGUAGE plpgsql AS $$ BEGIN END; $$;
      CREATE EVENT TRIGGER reassign_owned
        ON ddl_command_end EXECUTE FUNCTION noop_event_trigger();
    SQL
  end

  def build_dump(sql_transform: nil, include_materialized_view: true)
    materialized_view_drop_sql = 'DROP MATERIALIZED VIEW restore_probe_view;' if include_materialized_view
    materialized_view_create_sql = if include_materialized_view
                                     <<~SQL
                                       CREATE MATERIALIZED VIEW restore_probe_view AS
                                         SELECT value FROM restore_probe WITH NO DATA;
                                     SQL
                                   end

    dump = <<~SQL
      SET client_min_messages = warning;

      DROP EVENT TRIGGER reassign_owned;
      #{materialized_view_drop_sql}
      DROP TABLE restore_probe;
      DROP FUNCTION noop_event_trigger();

      CREATE TABLE restore_probe(value text);
      INSERT INTO restore_probe VALUES ('new');
      #{materialized_view_create_sql}
      CREATE FUNCTION noop_event_trigger() RETURNS event_trigger
        LANGUAGE plpgsql AS $$ BEGIN END; $$;
      CREATE EVENT TRIGGER reassign_owned
        ON ddl_command_end EXECUTE FUNCTION noop_event_trigger();
    SQL
    dump = sql_transform.call(dump) if sql_transform
    # Legacy dumps have no marker and must retain their original maintenance boundary.
    dump += "VACUUM FULL ANALYZE;\n"

    Zlib::GzipWriter.open(dump_file) { |gzip| gzip.write(dump) }
  end

  def install_replication_boundary_stubs
    FileUtils.mkdir_p(File.join(tempdir, 'bin'))
    FileUtils.touch(command_log)

    write_executable('aws', <<~'BASH')
      #!/usr/bin/env bash
      set -euo pipefail
      echo "aws $*" >> "$TMPDIR/commands.log"

      if [[ "$1 $2" == "ecs describe-services" ]]; then
        echo 1
      fi
    BASH

    write_executable('curl', <<~'BASH')
      #!/usr/bin/env bash
      set -euo pipefail
      echo "curl $*" >> "$TMPDIR/commands.log"

      while [[ $# -gt 0 ]]; do
        if [[ "$1" == "--output" ]]; then
          cp "$DUMP_FIXTURE" "$2"
          exit 0
        fi
        shift
      done

      exit 1
    BASH

    write_executable('psql', <<~'BASH')
      #!/usr/bin/env bash
      set -euo pipefail
      echo "psql $*" >> "$TMPDIR/commands.log"
      exec "$REAL_PSQL" "$@"
    BASH
  end

  def run_replication
    env = {
      'PATH' => "#{tempdir}/bin:#{ENV.fetch('PATH')}",
      'TMPDIR' => tempdir,
      'REAL_PSQL' => real_psql,
      'DUMP_FIXTURE' => dump_file,
      'ENVIRONMENT' => 'development',
      'CLUSTER_NAME' => 'test-cluster',
      'SERVICES' => 'backend-web backend-worker',
      'DB_DUMP_USER' => 'dump-user',
      'DB_DUMP_PASSWORD' => 'dump-password',
      'DB_DUMP_SERVER' => 'https://dumps.example.test',
      'RESTORE_FILE' => '/tariff.sql.gz',
      'DATABASE_URL' => target_database,
      'PGUSER' => database_user,
      'RETRY_MAX_ATTEMPTS' => '2',
      'RETRY_INITIAL_DELAY_SECONDS' => '1',
    }

    Open3.capture3(env, replicate_script, chdir: Rails.root.to_s)
  end

  def run_backup(source_database)
    FileUtils.mkdir_p(File.join(tempdir, 'bin'))

    write_executable('pg_dump', <<~'BASH')
      #!/usr/bin/env bash
      set -euo pipefail

      if [[ -n "${PG_DUMP_CONTAINER:-}" ]]; then
        exec docker exec --env "PGUSER=$PGUSER" "$PG_DUMP_CONTAINER" pg_dump "$@"
      fi

      exec "$REAL_PG_DUMP" "$@"
    BASH

    write_executable('aws', <<~'BASH')
      #!/usr/bin/env bash
      set -euo pipefail

      if [[ "$1 $2 $3" == "s3 cp -" ]]; then
        cat > "$DUMP_FIXTURE"
      fi
    BASH

    env = {
      'PATH' => "#{tempdir}/bin:#{ENV.fetch('PATH')}",
      'DUMP_FIXTURE' => dump_file,
      'PG_DUMP_CONTAINER' => pg_dump_container.to_s,
      'REAL_PG_DUMP' => real_pg_dump,
      'ENVIRONMENT' => 'production',
      'S3_BUCKET' => 'test-backups',
      'DATABASE_URL' => source_database,
      'PGUSER' => database_user,
    }

    Open3.capture3(env, backup_script, chdir: Rails.root.to_s)
  end

  def evaluation_tables
    %w[
      evaluation_experiments
      evaluation_gold_queries
      evaluation_gold_query_sets
      evaluation_results
      evaluation_runs
      evaluation_synthetic_input_set_items
      evaluation_synthetic_input_sets
      tariff_knowledge_synthetic_atars
    ]
  end

  def evaluation_only_migration = '20261014090000_add_label_to_evaluation_runs.rb'

  def shared_evaluation_migration = '20260803000001_create_evaluation_experiments.rb'

  def production_only_evaluation_migration = '20261019130000_add_source_workbook_and_row_to_synthetic_atars.rb'

  # The tariff schema both environments share: a tariff table, its materialized view, the migration
  # history table and, unless left out, the eight evaluation tables with their real foreign keys and
  # identity columns. Rows are added separately.
  def create_tariff_schema(database, evaluation: true, event_trigger: false)
    psql(database, <<~SQL)
      CREATE SCHEMA uk;
      CREATE TABLE uk.goods_nomenclatures(id integer GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY, code text);
      CREATE MATERIALIZED VIEW uk.goods_nomenclature_codes AS SELECT code FROM uk.goods_nomenclatures;
      CREATE TABLE uk.schema_migrations(filename text NOT NULL);
    SQL

    psql(database, <<~SQL) if evaluation
      CREATE TABLE uk.tariff_knowledge_synthetic_atars(id integer GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY, label text);
      CREATE TABLE uk.evaluation_synthetic_input_sets(id integer GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY, name text);
      CREATE TABLE uk.evaluation_synthetic_input_set_items(
        id integer GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
        set_id integer REFERENCES uk.evaluation_synthetic_input_sets(id) ON DELETE CASCADE,
        synthetic_atar_id integer REFERENCES uk.tariff_knowledge_synthetic_atars(id) ON DELETE RESTRICT
      );
      CREATE TABLE uk.evaluation_gold_query_sets(id integer GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY, name text);
      CREATE TABLE uk.evaluation_gold_queries(
        id integer GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
        set_id integer REFERENCES uk.evaluation_gold_query_sets(id) ON DELETE CASCADE
      );
      CREATE TABLE uk.evaluation_experiments(
        id integer GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
        name text,
        gold_query_set_id integer REFERENCES uk.evaluation_gold_query_sets(id) ON DELETE RESTRICT,
        synthetic_input_set_id integer REFERENCES uk.evaluation_synthetic_input_sets(id) ON DELETE RESTRICT
      );
      CREATE TABLE uk.evaluation_runs(
        id integer GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
        label text,
        experiment_id integer REFERENCES uk.evaluation_experiments(id) ON DELETE RESTRICT
      );
      CREATE TABLE uk.evaluation_results(
        id integer GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
        run_id integer REFERENCES uk.evaluation_runs(id) ON DELETE CASCADE
      );
    SQL

    psql(database, <<~SQL) if event_trigger
      CREATE FUNCTION public.noop_event_trigger() RETURNS event_trigger
        LANGUAGE plpgsql AS $$ BEGIN END; $$;
      CREATE EVENT TRIGGER reassign_owned
        ON ddl_command_end EXECUTE FUNCTION public.noop_event_trigger();
    SQL
  end

  def seed_evaluation_data(database, prefix:, runs:)
    psql(database, <<~SQL)
      INSERT INTO uk.tariff_knowledge_synthetic_atars(label) VALUES ('#{prefix}-atar');
      INSERT INTO uk.evaluation_synthetic_input_sets(name) VALUES ('#{prefix}-set');
      INSERT INTO uk.evaluation_synthetic_input_set_items(set_id, synthetic_atar_id) VALUES (1, 1);
      INSERT INTO uk.evaluation_gold_query_sets(name) VALUES ('#{prefix}-gold-set');
      INSERT INTO uk.evaluation_gold_queries(set_id) VALUES (1);
      INSERT INTO uk.evaluation_experiments(name, synthetic_input_set_id) VALUES ('#{prefix}-experiment', 1);
      INSERT INTO uk.evaluation_runs(label, experiment_id)
        SELECT '#{prefix}-run-' || n, 1 FROM generate_series(1, #{runs}) AS n;
      INSERT INTO uk.evaluation_results(run_id) VALUES (1);
    SQL
  end

  def create_production_database
    database = "replication_source_#{SecureRandom.hex(6)}"
    run_command('createdb', '--username', database_user, database)
    create_tariff_schema(database, event_trigger: true)
    psql(database, <<~SQL)
      INSERT INTO uk.goods_nomenclatures(code) VALUES ('0101-production');
      INSERT INTO uk.schema_migrations VALUES
        ('20200101000000_create_goods.rb'),
        ('#{shared_evaluation_migration}'),
        ('#{production_only_evaluation_migration}');
    SQL
    seed_evaluation_data(database, prefix: 'production', runs: 3)
    database
  end

  # Staging: the same tables, plus a newer local column, different rows, and its own migration history.
  def prepare_staging_database(evaluation: true)
    create_tariff_schema(target_database, evaluation:)
    psql(target_database, <<~SQL)
      INSERT INTO uk.goods_nomenclatures(code) VALUES ('0101-staging');
      REFRESH MATERIALIZED VIEW uk.goods_nomenclature_codes;
      INSERT INTO uk.schema_migrations VALUES ('20200101000001_local_only.rb')
    SQL
    return unless evaluation

    psql(target_database, <<~SQL)
      INSERT INTO uk.schema_migrations VALUES ('#{shared_evaluation_migration}'), ('#{evaluation_only_migration}');
      ALTER TABLE uk.evaluation_runs ADD COLUMN newer_local_column text;
    SQL
    seed_evaluation_data(target_database, prefix: 'staging', runs: 1)
    psql(target_database, "UPDATE uk.evaluation_runs SET newer_local_column = 'kept'")
  end

  def evaluation_snapshot(database)
    evaluation_tables.index_with do |table|
      query(database, "SELECT coalesce(md5(string_agg(t::text, '|' ORDER BY t.id)), 'empty') FROM uk.#{table} t")
    end
  end

  def migrations(database)
    query(database, 'SELECT filename FROM uk.schema_migrations ORDER BY filename').lines.map(&:strip)
  end

  def replicate_from(source_database)
    _stdout, backup_stderr, backup_status = run_backup(source_database)
    raise "backup failed:\n#{backup_stderr}" unless backup_status.success?

    install_replication_boundary_stubs
    run_replication
  end

  before do
    @replicate_script = Rails.root.join('bin/db-replicate').to_s
    @backup_script = Rails.root.join('bin/backup-database').to_s
    @target_database = "replication_target_#{SecureRandom.hex(6)}"
    @tempdir = Dir.mktmpdir
    @command_log = File.join(tempdir, 'commands.log')
    @dump_file = File.join(tempdir, 'production.sql.gz')
    @database_user = [ENV['PGUSER'], ENV['DB_USER'], ENV['USER'], 'postgres']
                       .compact
                       .uniq
                       .find do |candidate|
      _stdout, _stderr, status = Open3.capture3(
        'psql',
        '-X',
        '--username',
        candidate,
        '-d',
        'postgres',
        '-Atqc',
        'SELECT 1',
      )
      status.success?
    end
    @real_psql = ENV.fetch('PATH')
                      .split(File::PATH_SEPARATOR)
                      .map { |directory| File.join(directory, 'psql') }
                      .find { |path| File.executable?(path) }
    @real_pg_dump = ENV.fetch('PATH')
                       .split(File::PATH_SEPARATOR)
                       .map { |directory| File.join(directory, 'pg_dump') }
                       .find { |path| File.executable?(path) }
    server_major = query('postgres', 'SHOW server_version_num').to_i / 10_000
    client_major = run_command(real_pg_dump, '--version')[/\d+/].to_i
    @pg_dump_container = if server_major != client_major
                           run_command(
                             'docker',
                             'ps',
                             '--filter',
                             'publish=5432',
                             '--format',
                             '{{.ID}}',
                           ).lines.first&.strip
                         end

    create_target_database
  end

  after do
    run_command('dropdb', '--username', database_user, '--if-exists', '--force', target_database)
    FileUtils.remove_entry(tempdir)
  end

  it 'restores a legacy production-shaped dump and completes post-restore maintenance' do
    psql(target_database, 'DROP EVENT TRIGGER reassign_owned')
    build_dump
    install_replication_boundary_stubs

    _stdout, stderr, status = run_replication

    expect(status).to be_success, stderr
    expect(query(target_database, 'TABLE restore_probe')).to eq('new')
    expect(query(target_database, 'TABLE restore_probe_view')).to eq('new')
    expect(query(target_database, <<~SQL)).to eq('1')
      SELECT count(*) FROM pg_event_trigger WHERE evtname = 'reassign_owned'
    SQL
    expect(query(target_database, <<~SQL)).to eq('t')
      SELECT pg_try_advisory_lock(
        hashtextextended('trade-tariff-database-replication', 0)
      )
    SQL
  end

  it 'analyzes without rewriting tables' do
    original_filenode = query(target_database, "SELECT pg_relation_filenode('restore_probe')")
    psql(target_database, 'REFRESH MATERIALIZED VIEW restore_probe_view WITH NO DATA')

    run_command(
      'psql', '-X', '--username', database_user, '-v', 'ON_ERROR_STOP=1',
      '-d', target_database, '-f', Rails.root.join('bin/after.sql').to_s
    )

    expect(query(target_database, "SELECT pg_relation_filenode('restore_probe')")).to eq(original_filenode)
    expect(query(target_database, <<~SQL)).to eq('1')
      SELECT count(*) FROM pg_stats
      WHERE schemaname = 'public' AND tablename = 'restore_probe' AND attname = 'value'
    SQL
    expect(query(target_database, 'TABLE restore_probe_view')).to eq('old')
  end

  it 'completes post-restore maintenance when there are no materialized views' do
    psql(target_database, 'DROP MATERIALIZED VIEW restore_probe_view')
    build_dump(include_materialized_view: false)
    install_replication_boundary_stubs

    _stdout, stderr, status = run_replication

    expect(status).to be_success, stderr
    expect(query(target_database, 'TABLE restore_probe')).to eq('new')
  end

  it 'rolls back destructive statements and does not retry a deterministic SQL failure' do
    build_dump(
      sql_transform: lambda { |dump|
        dump.sub(
          "DROP EVENT TRIGGER reassign_owned;\n",
          "DROP EVENT TRIGGER reassign_owned;\nSELECT 1 / 0;\n",
        )
      },
    )
    install_replication_boundary_stubs

    _stdout, _stderr, status = run_replication

    expect(status).not_to be_success
    expect(query(target_database, 'TABLE restore_probe')).to eq('old')
    expect(query(target_database, <<~SQL)).to eq('1')
      SELECT count(*) FROM pg_event_trigger WHERE evtname = 'reassign_owned'
    SQL
    core_restores = File.readlines(command_log).grep(/psql -X -v ON_ERROR_STOP=1/)
    expect(core_restores.length).to eq(1)
    expect(File.readlines(command_log).grep(/aws ecs update-service .*--desired-count 1/).length).to eq(2)
  end

  it 'does not mutate services or the target when another replication holds the lock' do
    build_dump
    install_replication_boundary_stubs

    Open3.popen3(
      real_psql,
      '-X',
      '--username',
      database_user,
      '-qAt',
      target_database,
    ) do |stdin, stdout, _stderr, wait_thread|
      stdin.puts <<~SQL
        SELECT pg_try_advisory_lock(
          hashtextextended('trade-tariff-database-replication', 0)
        );
      SQL
      stdin.flush
      expect(stdout.gets&.strip).to eq('t')

      _replication_stdout, replication_stderr, status = run_replication

      expect(status).not_to be_success
      expect(replication_stderr).to include('Another database replication is already running')
      expect(File.readlines(command_log).grep(/aws ecs/)).to be_empty
      expect(query(target_database, 'TABLE restore_probe')).to eq('old')

      stdin.close
      Process.kill('TERM', wait_thread.pid) if wait_thread.alive?
    end
  end

  it 'restores a dump produced by the real backup pipeline' do
    source_database = "replication_source_#{SecureRandom.hex(6)}"
    run_command('createdb', '--username', database_user, source_database)

    begin
      psql(source_database, <<~SQL)
        CREATE TABLE restore_probe(value text);
        INSERT INTO restore_probe VALUES ('from-backup');
        CREATE MATERIALIZED VIEW restore_probe_view AS
          SELECT value FROM restore_probe;
        CREATE SCHEMA xi;
        CREATE TABLE xi.restore_probe(value text);
        INSERT INTO xi.restore_probe VALUES ('from-backup');
        CREATE FUNCTION noop_event_trigger() RETURNS event_trigger
          LANGUAGE plpgsql AS $$ BEGIN END; $$;
        CREATE EVENT TRIGGER reassign_owned
          ON ddl_command_end EXECUTE FUNCTION noop_event_trigger();
      SQL

      expect(query(source_database, 'TABLE restore_probe')).to eq('from-backup')

      _stdout, backup_stderr, backup_status = run_backup(source_database)
      expect(backup_status).to be_success, backup_stderr
      backup_sql = Zlib::GzipReader.open(dump_file, &:read)
      expect(backup_sql).to include('COPY public.restore_probe'), backup_stderr
      expect(backup_sql).to include("from-backup\n")

      install_replication_boundary_stubs
      _stdout, replication_stderr, replication_status = run_replication

      expect(replication_status).to be_success, replication_stderr
      expect(query(target_database, 'TABLE restore_probe')).to eq('from-backup')
      expect(query(target_database, 'TABLE xi.restore_probe')).to eq('from-backup')
      expect(query(target_database, 'TABLE restore_probe_view')).to eq('from-backup')
    ensure
      run_command('dropdb', '--username', database_user, '--if-exists', '--force', source_database)
    end
  end

  it 'emits a restartable dump with an explicit maintenance boundary' do
    FileUtils.mkdir_p(File.join(tempdir, 'bin'))

    write_executable('pg_dump', <<~'BASH')
      #!/usr/bin/env bash
      set -euo pipefail

      if [[ " $* " != *" --if-exists "* ]]; then
        echo "missing --if-exists" >&2
        exit 42
      fi

      printf 'DROP EVENT TRIGGER IF EXISTS reassign_owned;\n'
      printf 'DROP SCHEMA IF EXISTS xi;\n'
    BASH

    write_executable('gzip', <<~'BASH')
      #!/usr/bin/env bash
      exec cat
    BASH

    write_executable('aws', <<~'BASH')
      #!/usr/bin/env bash
      set -euo pipefail

      if [[ "$1 $2 $3" == "s3 cp -" ]]; then
        cat > "$TMPDIR/uploaded.sql"
      fi
    BASH

    env = {
      'PATH' => "#{tempdir}/bin:#{ENV.fetch('PATH')}",
      'TMPDIR' => tempdir,
      'ENVIRONMENT' => 'production',
      'S3_BUCKET' => 'test-backups',
      'DATABASE_URL' => target_database,
      'PGUSER' => database_user,
    }

    _stdout, stderr, status = Open3.capture3(env, backup_script, chdir: Rails.root.to_s)
    uploaded_dump = File.read(File.join(tempdir, 'uploaded.sql'))

    expect(status).to be_success, stderr
    expect(uploaded_dump).to include('DROP EVENT TRIGGER IF EXISTS reassign_owned;')
    expect(uploaded_dump).to include('DROP SCHEMA IF EXISTS xi CASCADE;')
    expect(uploaded_dump).not_to include('IF EXISTS IF EXISTS')
    expect(uploaded_dump).to include("-- TRADE_TARIFF_POST_RESTORE_START\n")
    expect(uploaded_dump).to include("\nANALYZE;\n")
    expect(uploaded_dump).not_to include('VACUUM')
  end

  it 'does not replace the latest backup when pg_dump fails' do
    FileUtils.mkdir_p(File.join(tempdir, 'bin'))

    write_executable('pg_dump', <<~'BASH')
      #!/usr/bin/env bash
      printf '%s\n' '-- incomplete dump'
      exit 42
    BASH

    write_executable('gzip', <<~'BASH')
      #!/usr/bin/env bash
      exec cat
    BASH

    write_executable('aws', <<~'BASH')
      #!/usr/bin/env bash
      set -euo pipefail
      echo "$*" >> "$TMPDIR/aws-commands.log"
      cat > /dev/null
    BASH

    env = {
      'PATH' => "#{tempdir}/bin:#{ENV.fetch('PATH')}",
      'TMPDIR' => tempdir,
      'ENVIRONMENT' => 'production',
      'S3_BUCKET' => 'test-backups',
      'DATABASE_URL' => target_database,
      'PGUSER' => database_user,
    }

    _stdout, _stderr, status = Open3.capture3(env, backup_script, chdir: Rails.root.to_s)
    aws_commands = File.readlines(File.join(tempdir, 'aws-commands.log'), chomp: true)

    expect(status.exitstatus).to eq(2)
    expect(aws_commands).not_to include(
      's3 cp - s3://test-backups/tariff-merged-production.sql.gz',
    )
  end

  describe 'keeping the evaluation tables' do
    let(:source_database) { create_production_database }

    before { prepare_staging_database }

    after do
      run_command('dropdb', '--username', database_user, '--if-exists', '--force', source_database)
    end

    it 'replaces tariff data from production and leaves all eight evaluation tables exactly as they were' do
      evaluation_before = evaluation_snapshot(target_database)

      _stdout, stderr, status = replicate_from(source_database)

      expect(status).to be_success, stderr
      expect(query(target_database, 'TABLE uk.goods_nomenclatures')).to eq('1|0101-production')
      expect(evaluation_snapshot(target_database)).to eq(evaluation_before)
    end

    it 'keeps newer local columns and sequence state on the evaluation tables' do
      _stdout, stderr, status = replicate_from(source_database)

      expect(status).to be_success, stderr
      expect(query(target_database, 'SELECT newer_local_column FROM uk.evaluation_runs')).to eq('kept')
      expect(query(target_database, "INSERT INTO uk.evaluation_runs(label) VALUES ('next') RETURNING id")).to start_with('2')
    end

    it 'leaves no holding schema behind' do
      _stdout, stderr, status = replicate_from(source_database)

      expect(status).to be_success, stderr
      expect(query(target_database, "SELECT count(*) FROM pg_namespace WHERE nspname = 'replication_holding'")).to eq('0')
    end

    it 'keeps the local applied state of evaluation migrations and restores the rest of the history from production' do
      _stdout, stderr, status = replicate_from(source_database)

      expect(status).to be_success, stderr
      expect(migrations(target_database)).to eq(
        ['20200101000000_create_goods.rb', shared_evaluation_migration, evaluation_only_migration].sort,
      )
    end

    it 'leaves a production-only evaluation migration unapplied, because the kept tables do not have its change' do
      _stdout, stderr, status = replicate_from(source_database)

      expect(status).to be_success, stderr
      expect(migrations(target_database)).not_to include(production_only_evaluation_migration)
    end

    it 'removes a table from an unreleased staging migration together with its migration record' do
      psql(target_database, 'CREATE TABLE uk.staging_only(id integer)')
      psql(target_database, "INSERT INTO uk.schema_migrations VALUES ('20261026000000_create_staging_only.rb')")

      _stdout, stderr, status = replicate_from(source_database)

      expect(status).to be_success, stderr
      expect(query(target_database, "SELECT to_regclass('uk.staging_only') IS NULL")).to eq('t')
      expect(migrations(target_database)).not_to include('20261026000000_create_staging_only.rb')
    end

    it 'refreshes materialized views in post-restore maintenance' do
      _stdout, stderr, status = replicate_from(source_database)

      expect(status).to be_success, stderr
      expect(query(target_database, 'TABLE uk.goods_nomenclature_codes')).to eq('0101-production')
    end

    it 'rolls everything back when a restore statement fails' do
      _stdout, backup_stderr, backup_status = run_backup(source_database)
      expect(backup_status).to be_success, backup_stderr
      install_replication_boundary_stubs
      write_executable('gzip', <<~'BASH')
        #!/usr/bin/env bash
        printf 'SELECT 1 / 0;\n'
        PATH="${PATH#*:}" gzip "$@"
      BASH
      evaluation_before = evaluation_snapshot(target_database)

      _stdout, _stderr, status = run_replication

      expect(status).not_to be_success
      expect(query(target_database, 'TABLE uk.goods_nomenclatures')).to eq('1|0101-staging')
      expect(migrations(target_database)).to include('20200101000001_local_only.rb')
      expect(evaluation_snapshot(target_database)).to eq(evaluation_before)
      expect(query(target_database, "SELECT count(*) FROM pg_namespace WHERE nspname = 'replication_holding'")).to eq('0')
    end

    it 'rolls everything back, and commits nothing, when the dump cannot be read to the end' do
      _stdout, backup_stderr, backup_status = run_backup(source_database)
      expect(backup_status).to be_success, backup_stderr
      install_replication_boundary_stubs
      write_executable('gzip', <<~'BASH')
        #!/usr/bin/env bash
        PATH="${PATH#*:}" gzip "$@" | head -c 6000
        exit 1
      BASH
      evaluation_before = evaluation_snapshot(target_database)

      _stdout, _stderr, status = run_replication

      expect(status).not_to be_success
      expect(query(target_database, 'TABLE uk.goods_nomenclatures')).to eq('1|0101-staging')
      expect(migrations(target_database)).to include('20200101000001_local_only.rb')
      expect(evaluation_snapshot(target_database)).to eq(evaluation_before)
    end
  end

  describe 'when the target has no evaluation tables yet' do
    let(:source_database) { create_production_database }

    before { prepare_staging_database(evaluation: false) }

    after do
      run_command('dropdb', '--username', database_user, '--if-exists', '--force', source_database)
    end

    it 'restores production\'s evaluation tables and migration history, since there is nothing local to keep' do
      _stdout, stderr, status = replicate_from(source_database)

      expect(status).to be_success, stderr
      expect(query(target_database, 'SELECT count(*) FROM uk.evaluation_runs')).to eq('3')
      expect(migrations(target_database)).to eq(
        ['20200101000000_create_goods.rb', shared_evaluation_migration, production_only_evaluation_migration].sort,
      )
    end
  end
end
