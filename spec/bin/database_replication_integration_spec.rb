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
    dump += Rails.root.join('bin/after.sql').read

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
      'ENVIRONMENT' => 'production',
      'S3_BUCKET' => 'test-backups',
      'DATABASE_URL' => source_database,
      'PGUSER' => database_user,
    }

    Open3.capture3(env, backup_script, chdir: Rails.root.to_s)
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
    core_restores = File.readlines(command_log).grep(/psql --single-transaction/)
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

      _stdout, backup_stderr, backup_status = run_backup(source_database)
      expect(backup_status).to be_success, backup_stderr
      backup_sql = Zlib::GzipReader.open(dump_file, &:read)
      expect(backup_sql).to include('COPY public.restore_probe')
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
  end
end
