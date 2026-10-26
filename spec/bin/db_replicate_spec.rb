# frozen_string_literal: true

require 'open3'
require 'tmpdir'

RSpec.describe 'bin/db-replicate' do
  let(:script_path) { File.expand_path('../../bin/db-replicate', __dir__) }
  let(:tempdir) { Dir.mktmpdir }

  def write_executable(path, contents)
    File.write(path, contents)
    File.chmod(0o755, path)
  end

  def run_replicate(tempdir, env_overrides = {})
    env = {
      'PATH' => "#{tempdir}/bin:#{ENV.fetch('PATH')}",
      'TMPDIR' => tempdir,
      'ENVIRONMENT' => 'development',
      'CLUSTER_NAME' => 'test-cluster',
      'SERVICES' => 'backend-web backend-worker',
      'DB_DUMP_USER' => 'dump-user',
      'DB_DUMP_PASSWORD' => 'dump-password',
      'DB_DUMP_SERVER' => 'https://dumps.example.test',
      'RESTORE_FILE' => '/tariff-merged-production.replication.dump',
      'DATABASE_URL' => 'postgres://database.example.test/tariff',
    }.merge(env_overrides)

    Open3.capture3(env, script_path, chdir: File.expand_path('../..', __dir__))
  end

  def command_log(tempdir)
    File.readlines("#{tempdir}/commands.log", chomp: true)
  end

  def touch_flag(name)
    FileUtils.touch("#{tempdir}/#{name}")
  end

  def install_successful_command_stubs
    write_executable "#{tempdir}/bin/aws", <<~'BASH'
      #!/usr/bin/env bash
      set -euo pipefail
      echo "aws $*" >> "$TMPDIR/commands.log"

      attempts_file_for() {
        printf '%s/%s' "$TMPDIR" "$1"
      }

      fail_once_when_flagged() {
        local flag=$1
        local attempts_file
        attempts_file=$(attempts_file_for "$2")

        if [[ ! -f "$TMPDIR/$flag" ]]; then
          return 0
        fi

        attempts=0
        [[ -f "$attempts_file" ]] && attempts=$(cat "$attempts_file")
        attempts=$((attempts + 1))
        echo "$attempts" > "$attempts_file"

        if [[ "$attempts" -eq 1 ]]; then
          echo "temporary aws failure" >&2
          exit 42
        fi
      }

      if [[ "$1 $2" == "ecs describe-services" ]]; then
        fail_once_when_flagged fail_describe_backend_web_once backend-web-describe-attempts

        if [[ -f "$TMPDIR/invalid_describe_backend_web_once" && "$*" == *"backend-web"* ]]; then
          attempts_file="$TMPDIR/backend-web-invalid-describe-attempts"
          attempts=0
          [[ -f "$attempts_file" ]] && attempts=$(cat "$attempts_file")
          attempts=$((attempts + 1))
          echo "$attempts" > "$attempts_file"

          if [[ "$attempts" -eq 1 ]]; then
            echo None
            exit 0
          fi
        fi

        case "$*" in
          *backend-web*) echo 2 ;;
          *backend-worker*)
            if [[ -f "$TMPDIR/backend_worker_desired_zero" ]]; then
              echo 0
            else
              echo 1
            fi
            ;;
          *) echo 1 ;;
        esac
        exit 0
      fi

      if [[ "$1 $2" == "ecs wait" ]]; then
        if [[ -f "$TMPDIR/always_fail_backend_web_stop_wait" && -f "$TMPDIR/backend-web-last-update-stop" ]]; then
          echo "permanent backend-web stop waiter failure" >&2
          exit 42
        fi

        fail_once_when_flagged fail_backend_web_wait_once backend-web-wait-attempts
      fi

      if [[ "$1 $2" == "ecs update-service" && "$*" == *"backend-web"* && "$*" == *"--desired-count 0"* ]]; then
        touch "$TMPDIR/backend-web-last-update-stop"
        rm -f "$TMPDIR/backend-web-last-update-start"
        fail_once_when_flagged fail_backend_web_stop_once backend-web-stop-attempts
      fi

      if [[ "$1 $2" == "ecs update-service" && "$*" == *"backend-worker"* && "$*" == *"--desired-count 0"* ]]; then
        if [[ -f "$TMPDIR/always_fail_backend_worker_stop" ]]; then
          echo "permanent backend-worker stop failure" >&2
          exit 42
        fi
      fi

      if [[ "$1 $2" == "ecs update-service" && "$*" == *"backend-web"* && "$*" == *"--desired-count 2"* ]]; then
        touch "$TMPDIR/backend-web-last-update-start"
        rm -f "$TMPDIR/backend-web-last-update-stop"
        if [[ -f "$TMPDIR/always_fail_backend_web_start" ]]; then
          echo "permanent backend-web start failure" >&2
          exit 42
        fi

        fail_once_when_flagged fail_backend_web_start_once backend-web-start-attempts
      fi

      if [[ "$1 $2" == "s3 sync" ]]; then
        fail_once_when_flagged fail_s3_sync_once s3-sync-attempts
      fi
    BASH

    write_executable "#{tempdir}/bin/curl", <<~'BASH'
      #!/usr/bin/env bash
      set -euo pipefail
      echo "curl $*" >> "$TMPDIR/commands.log"

      if [[ -f "$TMPDIR/fail_curl_once" ]]; then
        attempts_file="$TMPDIR/curl-attempts"
        attempts=0
        [[ -f "$attempts_file" ]] && attempts=$(cat "$attempts_file")
        attempts=$((attempts + 1))
        echo "$attempts" > "$attempts_file"

        if [[ "$attempts" -eq 1 ]]; then
          echo "temporary curl failure" >&2
          exit 42
        fi
      fi

      if [[ -f "$TMPDIR/always_fail_curl" ]]; then
        echo "permanent curl failure" >&2
        exit 42
      fi

      output_file=''
      while [[ $# -gt 0 ]]; do
        if [[ "$1" == "--output" ]]; then
          output_file=$2
          shift 2
        else
          shift
        fi
      done

      printf 'archive\n' > "$output_file"
    BASH

    write_executable "#{tempdir}/bin/pg_restore", <<~'BASH'
      #!/usr/bin/env bash
      set -euo pipefail
      echo "pg_restore $*" >> "$TMPDIR/commands.log"

      if [[ "$1" == "--list" ]]; then
        if [[ -f "$TMPDIR/fail_pg_restore_list" ]]; then
          echo "input file does not appear to be a valid archive" >&2
          exit 1
        fi

        printf '%s\n' '; Archive created at 2026-10-26 12:00:00 GMT'
        printf '%s\n' '6; 2615 100 SCHEMA - uk owner'
        printf '%s\n' '215; 1259 101 TABLE uk goods_nomenclatures owner'
        printf '%s\n' '3364; 0 101 TABLE DATA uk goods_nomenclatures owner'
        printf '%s\n' '3400; 0 102 MATERIALIZED VIEW DATA uk goods_nomenclature_codes owner'

        if [[ -f "$TMPDIR/archive_contains_excluded_table" ]]; then
          printf '%s\n' '216; 1259 103 TABLE uk evaluation_runs owner'
        fi

        exit 0
      fi

      for argument in "$@"; do
        case "$argument" in
          --use-list=*) cp "${argument#--use-list=}" "$TMPDIR/use-list.txt" ;;
        esac
      done

      if [[ -f "$TMPDIR/always_fail_pg_restore" ]]; then
        printf 'CREATE TABLE half_restored_table(id integer);\n'
        echo "permanent pg_restore failure" >&2
        exit 42
      fi

      printf 'SET transaction_timeout = 0;\n'
      printf 'CREATE TABLE restored_table(id integer);\n'
    BASH

    write_executable "#{tempdir}/bin/psql", <<~'BASH'
      #!/usr/bin/env bash
      set -euo pipefail
      echo "psql $*" >> "$TMPDIR/commands.log"

      if [[ "$*" == *"-qAt"* ]]; then
        IFS= read -r lock_query
        echo "lock-query $lock_query" >> "$TMPDIR/commands.log"

        if [[ -f "$TMPDIR/replication_lock_unavailable" ]]; then
          printf 'f\n'
        else
          printf 't\n'
        fi

        cat > /dev/null
        exit 0
      fi

      if [[ "$1" == "-X" ]]; then
        cat > "$TMPDIR/core-restore.sql"

        if [[ -f "$TMPDIR/always_fail_core_restore" ]]; then
          echo "permanent core restore failure" >&2
          exit 42
        fi
      else
        cat > "$TMPDIR/post-restore.sql"

        if [[ -f "$TMPDIR/always_fail_post_restore" ]]; then
          echo "permanent post-restore failure" >&2
          exit 42
        fi
      fi

    BASH

    write_executable "#{tempdir}/bin/sleep", <<~'BASH'
      #!/usr/bin/env bash
      set -euo pipefail
      echo "sleep $*" >> "$TMPDIR/commands.log"
    BASH

    write_executable "#{tempdir}/bin/mktemp", <<~'BASH'
      #!/usr/bin/env bash
      set -euo pipefail
      echo "mktemp $*" >> "$TMPDIR/commands.log"

      counter_file="$TMPDIR/mktemp-count"
      count=0
      [[ -f "$counter_file" ]] && count=$(cat "$counter_file")
      count=$((count + 1))
      echo "$count" > "$counter_file"

      if [[ "$count" -eq 1 ]]; then
        path="$TMPDIR/database-dump.replication.dump"
      else
        path="$TMPDIR/scratch-$count"
      fi

      : > "$path"
      printf '%s\n' "$path"
    BASH

    write_executable "#{tempdir}/bin/rm", <<~'BASH'
      #!/usr/bin/env bash
      set -euo pipefail
      echo "rm $*" >> "$TMPDIR/commands.log"
      if [[ -f "$TMPDIR/always_fail_rm" && "$*" == *"database-dump.replication.dump"* ]]; then
        echo "permanent rm failure" >&2
        exit 42
      fi
      PATH="${PATH#*:}" command rm "$@"
    BASH
  end

  before do
    FileUtils.mkdir_p("#{tempdir}/bin")
    FileUtils.touch("#{tempdir}/commands.log")
  end

  after do
    FileUtils.remove_entry(tempdir)
  end

  it 'retries transient ECS update failures with exponential backoff' do
    install_successful_command_stubs
    touch_flag 'fail_backend_web_stop_once'

    stdout, stderr, status = run_replicate(tempdir)

    expect(status).to be_success, stderr
    expect(stdout).to include('Database replication and exchange rate syncing complete')
    expect(command_log(tempdir).grep(/aws ecs update-service .*backend-web.*--desired-count 0/).count).to eq(2)
    expect(command_log(tempdir)).to include(
      'aws ecs wait services-stable --cluster test-cluster --services backend-web',
    )
    expect(command_log(tempdir)).to include('sleep 5')
  end

  it 'retries transient ECS describe failures before stopping a service' do
    install_successful_command_stubs
    touch_flag 'fail_describe_backend_web_once'

    _stdout, stderr, status = run_replicate(tempdir)

    expect(status).to be_success, stderr
    expect(command_log(tempdir).grep(/aws ecs describe-services .*backend-web/).count).to eq(2)
    expect(command_log(tempdir)).to include('sleep 5')
  end

  it 'retries non-numeric ECS desired counts before stopping a service' do
    install_successful_command_stubs
    touch_flag 'invalid_describe_backend_web_once'

    _stdout, stderr, status = run_replicate(tempdir)

    expect(status).to be_success, stderr
    expect(command_log(tempdir).grep(/aws ecs describe-services .*backend-web/).count).to eq(2)
    expect(command_log(tempdir)).to include('sleep 5')
  end

  it 'restores the archive once in an explicit transaction and runs maintenance separately' do
    install_successful_command_stubs

    _stdout, stderr, status = run_replicate(tempdir)

    expect(status).to be_success, stderr
    expect(command_log(tempdir).grep(
      %r{\Apsql -X -v ON_ERROR_STOP=1 postgres://database\.example\.test/tariff\z},
    ).count).to eq(1)
    expect(command_log(tempdir).grep(/--single-transaction/)).to be_empty

    core_restore = File.read("#{tempdir}/core-restore.sql")
    expect(core_restore).to start_with("BEGIN;\n")
    expect(core_restore).to end_with("COMMIT;\n")
    expect(core_restore).to include('CREATE TABLE restored_table')
    expect(core_restore).not_to include('ANALYZE;')
    expect(File.read("#{tempdir}/post-restore.sql")).to include("\nANALYZE;\n")
    expect(File.read("#{tempdir}/post-restore.sql")).not_to include('VACUUM')
  end

  it 'restores from pg_restore with a list that leaves out schemas and materialized view data' do
    install_successful_command_stubs

    _stdout, stderr, status = run_replicate(tempdir)

    expect(status).to be_success, stderr
    use_list = File.read("#{tempdir}/use-list.txt")
    expect(use_list).to include('TABLE DATA uk goods_nomenclatures')
    expect(use_list).not_to include('SCHEMA - uk')
    expect(use_list).not_to include('MATERIALIZED VIEW DATA')
    expect(command_log(tempdir).grep(/\Apg_restore --clean --if-exists --no-owner --no-acl --use-list=.* --file=- /).count).to eq(1)
  end

  it 'does not pass pg_restore\'s SET transaction_timeout to servers that may not have it' do
    install_successful_command_stubs

    _stdout, stderr, status = run_replicate(tempdir)

    expect(status).to be_success, stderr
    expect(File.read("#{tempdir}/core-restore.sql")).not_to match(/^SET transaction_timeout = 0;$/)
    expect(File.read("#{tempdir}/core-restore.sql")).to include("current_setting('server_version_num')::int >= 170000")
  end

  it 'preserves the local applied state of the evaluation-only migrations around the restore' do
    install_successful_command_stubs

    _stdout, stderr, status = run_replicate(tempdir)

    expect(status).to be_success, stderr
    core_restore = File.read("#{tempdir}/core-restore.sql")
    saved = core_restore.index('CREATE TEMP TABLE replication_preserved_migrations')
    restored = core_restore.index('CREATE TABLE restored_table')
    put_back = core_restore.index('INSERT INTO uk.schema_migrations')
    expect(saved).to be < restored
    expect(restored).to be < put_back
    expect(core_restore).to include("'20260803000001_create_evaluation_experiments.rb'")
  end

  it 'never commits when pg_restore fails part-way through writing the restore script' do
    install_successful_command_stubs
    touch_flag 'always_fail_pg_restore'

    _stdout, stderr, status = run_replicate(tempdir)

    expect(status).not_to be_success
    expect(stderr).to include('nothing is committed')
    expect(File.read("#{tempdir}/core-restore.sql")).to include('half_restored_table')
    expect(File.read("#{tempdir}/core-restore.sql")).not_to include('COMMIT;')
    expect(command_log(tempdir).grep(/aws ecs update-service .*backend-web.*--desired-count 2/).count).to eq(1)
  end

  it 'refuses the full recovery backup before running any command' do
    install_successful_command_stubs

    _stdout, stderr, status = run_replicate(tempdir, 'RESTORE_FILE' => '/tariff-merged-production.sql.gz')

    expect(status).not_to be_success
    expect(stderr).to include('RESTORE_FILE must be a replication archive')
    expect(command_log(tempdir)).to be_empty
  end

  it 'rejects a file pg_restore cannot read, restarts services and does not touch the database' do
    install_successful_command_stubs
    touch_flag 'fail_pg_restore_list'

    _stdout, stderr, status = run_replicate(tempdir)

    expect(status).not_to be_success
    expect(stderr).to include('is not a valid replication archive')
    expect(command_log(tempdir).grep(/\Apsql -X -v ON_ERROR_STOP=1/)).to be_empty
    expect(command_log(tempdir).grep(/aws ecs update-service .*backend-web.*--desired-count 2/).count).to eq(1)
    expect(command_log(tempdir).grep(/aws s3 sync/)).to be_empty
  end

  it 'rejects an archive that contains an evaluation table, restarts services and does not touch the database' do
    install_successful_command_stubs
    touch_flag 'archive_contains_excluded_table'

    _stdout, stderr, status = run_replicate(tempdir)

    expect(status).not_to be_success
    expect(stderr).to include('contains uk.evaluation_runs')
    expect(command_log(tempdir).grep(/\Apsql -X -v ON_ERROR_STOP=1/)).to be_empty
    expect(command_log(tempdir).grep(/aws ecs update-service .*backend-web.*--desired-count 2/).count).to eq(1)
  end

  it 'acquires the replication lock before changing service desired counts' do
    install_successful_command_stubs

    _stdout, stderr, status = run_replicate(tempdir)

    expect(status).to be_success, stderr
    commands = command_log(tempdir)
    expect(commands.index { |command| command.start_with?('lock-query SELECT pg_try_advisory_lock') })
      .to be < commands.index { |command| command.match?(/aws ecs update-service/) }
  end

  it 'exits without changing services when another replication holds the lock' do
    install_successful_command_stubs
    touch_flag 'replication_lock_unavailable'

    _stdout, stderr, status = run_replicate(tempdir)

    expect(status).not_to be_success
    expect(stderr).to include('Another database replication is already running')
    expect(command_log(tempdir).grep(/aws ecs/)).to be_empty
    expect(command_log(tempdir).grep(/curl/)).to be_empty
  end

  it 'retries transient database download failures' do
    install_successful_command_stubs
    touch_flag 'fail_curl_once'

    _stdout, stderr, status = run_replicate(tempdir)

    expect(status).to be_success, stderr
    expect(command_log(tempdir).grep(%r{curl .*https://dumps.example.test/tariff-merged-production.replication.dump}).count).to eq(2)
    expect(command_log(tempdir)).to include('sleep 5')
  end

  it 'retries transient service restart failures' do
    install_successful_command_stubs
    touch_flag 'fail_backend_web_start_once'

    _stdout, stderr, status = run_replicate(tempdir)

    expect(status).to be_success, stderr
    expect(command_log(tempdir).grep(/aws ecs update-service .*backend-web.*--desired-count 2/).count).to eq(2)
    expect(command_log(tempdir).grep(/aws ecs wait services-stable .*backend-web/).count).to eq(2)
    expect(command_log(tempdir)).to include('sleep 5')
  end

  it 'attempts to stop every service and restarts services already stopped when a later stop fails' do
    install_successful_command_stubs
    touch_flag 'always_fail_backend_worker_stop'

    _stdout, stderr, status = run_replicate(tempdir, 'RETRY_MAX_ATTEMPTS' => '2')

    expect(status).not_to be_success
    expect(stderr).to include('Set desired count for backend-worker to 0 failed after 2 attempts')
    expect(command_log(tempdir).grep(/aws ecs update-service .*backend-web.*--desired-count 0/).count).to eq(1)
    expect(command_log(tempdir).grep(/aws ecs update-service .*backend-web.*--desired-count 2/).count).to be >= 1
    expect(command_log(tempdir).grep(/curl /)).to be_empty
  end

  it 'restarts a service when scaling to zero succeeded but waiting for stability fails' do
    install_successful_command_stubs
    touch_flag 'always_fail_backend_web_stop_wait'

    _stdout, stderr, status = run_replicate(tempdir, 'RETRY_MAX_ATTEMPTS' => '2')

    expect(status).not_to be_success
    expect(stderr).to include('Set desired count for backend-web to 0 failed after 2 attempts')
    expect(command_log(tempdir).grep(/aws ecs update-service .*backend-web.*--desired-count 0/).count).to eq(2)
    expect(command_log(tempdir).grep(/aws ecs update-service .*backend-web.*--desired-count 2/).count).to be >= 1
    expect(command_log(tempdir).grep(/curl /)).to be_empty
  end

  it 'attempts to restart every recorded service even when one service restart fails' do
    install_successful_command_stubs
    touch_flag 'always_fail_backend_web_start'

    _stdout, stderr, status = run_replicate(tempdir, 'RETRY_MAX_ATTEMPTS' => '2')

    expect(status).not_to be_success
    expect(stderr).to include('Set desired count for backend-web to 2 failed after 2 attempts')
    expect(command_log(tempdir).grep(/aws ecs update-service .*backend-worker.*--desired-count 1/).count).to be >= 1
  end

  it 'restores services to an original desired count of zero' do
    install_successful_command_stubs
    touch_flag 'backend_worker_desired_zero'

    _stdout, stderr, status = run_replicate(tempdir)

    expect(status).to be_success, stderr
    expect(command_log(tempdir).grep(/aws ecs update-service .*backend-worker.*--desired-count 0/).count).to eq(2)
    expect(command_log(tempdir).grep(/aws ecs update-service .*backend-worker.*--desired-count 1/)).to be_empty
  end

  it 'retries transient exchange rate sync failures' do
    install_successful_command_stubs
    touch_flag 'fail_s3_sync_once'

    _stdout, stderr, status = run_replicate(tempdir)

    expect(status).to be_success, stderr
    expect(command_log(tempdir).grep(%r{aws s3 sync s3://trade-tariff-persistence-382373577178/data/exchange_rates/ s3://trade-tariff-persistence-844815912454/data/exchange_rates/}).count).to eq(2)
    expect(command_log(tempdir)).to include('sleep 5')
  end

  it 'removes the downloaded database dump after successful restore' do
    install_successful_command_stubs

    _stdout, stderr, status = run_replicate(tempdir)

    expect(status).to be_success, stderr
    expect(command_log(tempdir).grep(/^mktemp/).count).to eq(3)
    expect(command_log(tempdir)).to include("rm -f #{tempdir}/database-dump.replication.dump")
    expect(File.exist?("#{tempdir}/database-dump.replication.dump")).to be(false)
  end

  it 'fails and restarts services when cleanup fails after successful restore' do
    install_successful_command_stubs
    touch_flag 'always_fail_rm'

    _stdout, stderr, status = run_replicate(tempdir, 'RETRY_MAX_ATTEMPTS' => '2')

    expect(status).not_to be_success
    expect(stderr).to include('Remove temporary database dump failed after 2 attempts')
    expect(command_log(tempdir).grep(/aws s3 sync/)).to be_empty
    expect(command_log(tempdir).grep(/aws ecs update-service .*backend-web.*--desired-count 2/).count).to be >= 1
  end

  it 'fails the core restore once when psql reports a SQL error' do
    install_successful_command_stubs
    touch_flag 'always_fail_core_restore'

    _stdout, stderr, status = run_replicate(tempdir, 'RETRY_MAX_ATTEMPTS' => '2')

    expect(status).not_to be_success
    expect(stderr).to include('permanent core restore failure')
    expect(command_log(tempdir).grep(/psql -X -v ON_ERROR_STOP=1/).count).to eq(1)
    expect(command_log(tempdir).grep(/aws s3 sync/)).to be_empty
  end

  it 'restarts stopped services when the transactional core restore fails' do
    install_successful_command_stubs
    touch_flag 'always_fail_core_restore'

    _stdout, _stderr, status = run_replicate(tempdir)

    expect(status).not_to be_success
    expect(command_log(tempdir).grep(
      %r{\Apsql -X -v ON_ERROR_STOP=1 postgres://database\.example\.test/tariff\z},
    ).count).to eq(1)
    expect(command_log(tempdir).grep(/aws ecs update-service .*backend-web.*--desired-count 2/).count).to eq(1)
    expect(command_log(tempdir).grep(/aws ecs update-service .*backend-worker.*--desired-count 1/).count).to eq(1)
    expect(command_log(tempdir).grep(/aws s3 sync/)).to be_empty
    expect(command_log(tempdir)).to include("rm -f #{tempdir}/database-dump.replication.dump")
    expect(File.exist?("#{tempdir}/database-dump.replication.dump")).to be(false)
  end

  it 'leaves services stopped when post-restore maintenance fails after the core commits' do
    install_successful_command_stubs
    touch_flag 'always_fail_post_restore'

    _stdout, stderr, status = run_replicate(tempdir)

    expect(status).not_to be_success
    expect(stderr).to include('Post-restore maintenance failed after the core database committed')
    expect(command_log(tempdir).grep(/aws ecs update-service .*--desired-count 2/)).to be_empty
    expect(command_log(tempdir).grep(/aws ecs update-service .*--desired-count 1/)).to be_empty
    expect(command_log(tempdir).grep(/aws s3 sync/)).to be_empty
  end

  it 'removes the temporary dump file when database download ultimately fails' do
    install_successful_command_stubs
    touch_flag 'always_fail_curl'

    _stdout, stderr, status = run_replicate(tempdir)

    expect(status).not_to be_success
    expect(stderr).to include('Download database dump failed after')
    expect(command_log(tempdir).grep(/curl /).count).to eq(6)
    expect(command_log(tempdir).grep(/aws s3 sync/)).to be_empty
    expect(command_log(tempdir)).to include("rm -f #{tempdir}/database-dump.replication.dump")
    expect(File.exist?("#{tempdir}/database-dump.replication.dump")).to be(false)
  end

  it 'reports missing required environment variables before running commands' do
    install_successful_command_stubs

    _stdout, stderr, status = run_replicate(tempdir, 'CLUSTER_NAME' => nil)

    expect(status).not_to be_success
    expect(stderr).to include('You need to set the CLUSTER_NAME environment variable.')
    expect(command_log(tempdir)).to be_empty
  end

  it 'reports invalid retry settings before running commands' do
    install_successful_command_stubs

    _stdout, stderr, status = run_replicate(tempdir, 'RETRY_MAX_ATTEMPTS' => 'not-a-number')

    expect(status).not_to be_success
    expect(stderr).to include('RETRY_MAX_ATTEMPTS must be a positive integer.')
    expect(command_log(tempdir)).to be_empty
  end

  it 'reports unsupported environments before running commands' do
    install_successful_command_stubs

    _stdout, stderr, status = run_replicate(tempdir, 'ENVIRONMENT' => 'qa')

    expect(status).not_to be_success
    expect(stderr).to include("Unsupported ENVIRONMENT 'qa'.")
    expect(command_log(tempdir)).to be_empty
  end

  it 'rejects production as a replication target before running commands' do
    install_successful_command_stubs

    _stdout, stderr, status = run_replicate(tempdir, 'ENVIRONMENT' => 'production')

    expect(status).not_to be_success
    expect(stderr).to include('ENVIRONMENT cannot be production for database replication.')
    expect(command_log(tempdir)).to be_empty
  end

  it 'reports invalid initial retry delay before running commands' do
    install_successful_command_stubs

    _stdout, stderr, status = run_replicate(tempdir, 'RETRY_INITIAL_DELAY_SECONDS' => '0')

    expect(status).not_to be_success
    expect(stderr).to include('RETRY_INITIAL_DELAY_SECONDS must be a positive integer.')
    expect(command_log(tempdir)).to be_empty
  end
end
