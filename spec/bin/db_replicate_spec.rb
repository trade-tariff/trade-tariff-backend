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
      'RESTORE_FILE' => '/tariff.sql.gz',
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

      printf 'dump' > "$output_file"
    BASH

    write_executable "#{tempdir}/bin/gzip", <<~'BASH'
      #!/usr/bin/env bash
      set -euo pipefail
      echo "gzip $*" >> "$TMPDIR/commands.log"

      if [[ -f "$TMPDIR/fail_gzip_once" ]]; then
        attempts_file="$TMPDIR/gzip-attempts"
        attempts=0
        [[ -f "$attempts_file" ]] && attempts=$(cat "$attempts_file")
        attempts=$((attempts + 1))
        echo "$attempts" > "$attempts_file"

        if [[ "$attempts" -eq 1 ]]; then
          echo "temporary gzip failure" >&2
          exit 42
        fi
      fi

      cat "${!#}"
    BASH

    write_executable "#{tempdir}/bin/psql", <<~'BASH'
      #!/usr/bin/env bash
      set -euo pipefail
      echo "psql $*" >> "$TMPDIR/commands.log"
      cat > /dev/null

      if [[ -f "$TMPDIR/simulate_sql_error" ]]; then
        if [[ "$*" == *"ON_ERROR_STOP=1"* ]]; then
          echo "simulated SQL error" >&2
          exit 42
        fi

        echo "simulated SQL error ignored" >&2
        exit 0
      fi

      if [[ -f "$TMPDIR/always_fail_psql" ]]; then
        echo "permanent psql failure" >&2
        exit 42
      fi

      if [[ -f "$TMPDIR/fail_psql_once" ]]; then
        attempts_file="$TMPDIR/psql-attempts"
        attempts=0
        [[ -f "$attempts_file" ]] && attempts=$(cat "$attempts_file")
        attempts=$((attempts + 1))
        echo "$attempts" > "$attempts_file"

        if [[ "$attempts" -eq 1 ]]; then
          echo "temporary psql failure" >&2
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
      path="$TMPDIR/database-dump.sql.gz"
      : > "$path"
      printf '%s\n' "$path"
    BASH

    write_executable "#{tempdir}/bin/rm", <<~'BASH'
      #!/usr/bin/env bash
      set -euo pipefail
      echo "rm $*" >> "$TMPDIR/commands.log"
      if [[ -f "$TMPDIR/always_fail_rm" && "$*" == *"database-dump.sql.gz"* ]]; then
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

  it 'retries transient database restore failures' do
    install_successful_command_stubs
    touch_flag 'fail_psql_once'

    _stdout, stderr, status = run_replicate(tempdir)

    expect(status).to be_success, stderr
    expect(command_log(tempdir).grep(/psql --single-transaction -v ON_ERROR_STOP=1 postgres:\/\/database.example.test\/tariff/).count).to eq(2)
    expect(command_log(tempdir)).to include('sleep 5')
  end

  it 'retries transient database download failures' do
    install_successful_command_stubs
    touch_flag 'fail_curl_once'

    _stdout, stderr, status = run_replicate(tempdir)

    expect(status).to be_success, stderr
    expect(command_log(tempdir).grep(%r{curl .*https://dumps.example.test/tariff.sql.gz}).count).to eq(2)
    expect(command_log(tempdir)).to include('sleep 5')
  end

  it 'retries transient database decompression failures' do
    install_successful_command_stubs
    touch_flag 'fail_gzip_once'

    _stdout, stderr, status = run_replicate(tempdir)

    expect(status).to be_success, stderr
    expect(command_log(tempdir).grep(/gzip -dc/).count).to eq(2)
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
    expect(command_log(tempdir).grep(/^mktemp/).count).to eq(1)
    expect(command_log(tempdir)).to include("rm -f #{tempdir}/database-dump.sql.gz")
    expect(File.exist?("#{tempdir}/database-dump.sql.gz")).to be(false)
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

  it 'fails restore when psql reports a SQL error' do
    install_successful_command_stubs
    touch_flag 'simulate_sql_error'

    _stdout, stderr, status = run_replicate(tempdir, 'RETRY_MAX_ATTEMPTS' => '2')

    expect(status).not_to be_success
    expect(stderr).to include('Restore database failed after 2 attempts')
    expect(command_log(tempdir).grep(/psql --single-transaction -v ON_ERROR_STOP=1/).count).to eq(2)
    expect(command_log(tempdir).grep(/aws s3 sync/)).to be_empty
  end

  it 'restarts stopped services when database restore ultimately fails' do
    install_successful_command_stubs
    touch_flag 'always_fail_psql'

    _stdout, stderr, status = run_replicate(tempdir)

    expect(status).not_to be_success
    expect(stderr).to include('Restore database failed after')
    expect(command_log(tempdir).grep(/psql --single-transaction -v ON_ERROR_STOP=1 postgres:\/\/database.example.test\/tariff/).count).to eq(6)
    expect(command_log(tempdir).grep(/^sleep /)).to include('sleep 5', 'sleep 10', 'sleep 20', 'sleep 40', 'sleep 80')
    expect(command_log(tempdir).grep(/aws ecs update-service .*backend-web.*--desired-count 2/).count).to eq(1)
    expect(command_log(tempdir).grep(/aws ecs update-service .*backend-worker.*--desired-count 1/).count).to eq(1)
    expect(command_log(tempdir).grep(/aws s3 sync/)).to be_empty
    expect(command_log(tempdir)).to include("rm -f #{tempdir}/database-dump.sql.gz")
    expect(File.exist?("#{tempdir}/database-dump.sql.gz")).to be(false)
  end

  it 'removes the temporary dump file when database download ultimately fails' do
    install_successful_command_stubs
    touch_flag 'always_fail_curl'

    _stdout, stderr, status = run_replicate(tempdir)

    expect(status).not_to be_success
    expect(stderr).to include('Download database dump failed after')
    expect(command_log(tempdir).grep(/curl /).count).to eq(6)
    expect(command_log(tempdir).grep(/aws s3 sync/)).to be_empty
    expect(command_log(tempdir)).to include("rm -f #{tempdir}/database-dump.sql.gz")
    expect(File.exist?("#{tempdir}/database-dump.sql.gz")).to be(false)
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
