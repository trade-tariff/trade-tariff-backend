# frozen_string_literal: true

require 'active_support/time'
require 'date'
require 'open3'
require 'tmpdir'

RSpec.describe 'bin/check-database-backup-freshness' do # rubocop:disable RSpec/DescribeClass
  let(:script_path) { File.expand_path('../../bin/check-database-backup-freshness', __dir__) }
  let(:tempdir) { Dir.mktmpdir }
  # The script derives the archive key from the backup's Europe/London date.
  let(:london_zone) { Time.find_zone!('Europe/London') }
  let(:latest_epoch) { london_zone.now.to_i - 60 }

  def write_executable(path, contents)
    File.write(path, contents)
    File.chmod(0o755, path)
  end

  def run_check(tempdir, env_overrides = {}, args = ['--publish'])
    env = {
      'PATH' => "#{tempdir}/bin:#{ENV.fetch('PATH')}",
      'TMPDIR' => tempdir,
      'ENVIRONMENT' => 'development',
      'S3_BUCKET' => 'trade-tariff-database-backups-test',
    }.merge(env_overrides)

    Open3.capture3(env, script_path, *args, chdir: File.expand_path('../..', __dir__))
  end

  def command_log(tempdir)
    File.readlines("#{tempdir}/commands.log", chomp: true)
  end

  def archive_keys_requested(tempdir)
    command_log(tempdir).grep(/head-object/).filter_map { |line| line[%r{--key (\S+/\S+)}, 1] }
  end

  def touch_flag(name)
    FileUtils.touch("#{tempdir}/#{name}")
  end

  def london_date(epoch)
    london_zone.at(epoch).strftime('%Y/%m/%d')
  end

  def aws_timestamp(epoch)
    london_zone.at(epoch).utc.strftime('%Y-%m-%dT%H:%M:%S+00:00')
  end

  # Archive candidates are date prefixed (2026/07/29/...), the latest key is not,
  # so the stub tells them apart by looking for a slash in the requested key.
  def install_command_stubs
    write_executable "#{tempdir}/bin/aws", <<~'BASH'
      #!/usr/bin/env bash
      set -euo pipefail
      echo "aws $*" >> "$TMPDIR/commands.log"

      if [[ "$1 $2" != "s3api head-object" ]]; then
        exit 0
      fi

      key=''
      args=("$@")
      for ((i = 0; i < ${#args[@]}; i++)); do
        if [[ "${args[$i]}" == "--key" ]]; then
          key="${args[$((i + 1))]}"
        fi
      done

      not_found() {
        echo "An error occurred (404) when calling the HeadObject operation: Not Found" >&2
        exit 254
      }

      if [[ "$key" != */* ]]; then
        if [[ -f "$TMPDIR/latest_head_error" ]]; then
          echo "An error occurred (AccessDenied) when calling the HeadObject operation" >&2
          exit 5
        fi

        if [[ -f "$TMPDIR/latest_missing" ]]; then
          not_found
        fi

        cat "$TMPDIR/latest_last_modified"
        exit 0
      fi

      attempts_file="$TMPDIR/archive-attempts"
      attempts=0
      [[ -f "$attempts_file" ]] && attempts=$(cat "$attempts_file")
      attempts=$((attempts + 1))
      echo "$attempts" > "$attempts_file"

      if [[ -f "$TMPDIR/archive_missing_all" ]]; then
        not_found
      fi

      if [[ -f "$TMPDIR/archive_previous_day" && "$attempts" -eq 1 ]]; then
        not_found
      fi

      if [[ -f "$TMPDIR/archive_unparseable" ]]; then
        echo "not-a-timestamp"
        exit 0
      fi

      cat "$TMPDIR/archive_last_modified"
      exit 0
    BASH
  end

  before do
    FileUtils.mkdir_p("#{tempdir}/bin")
    FileUtils.touch("#{tempdir}/commands.log")
    File.write("#{tempdir}/latest_last_modified", aws_timestamp(latest_epoch))
    File.write("#{tempdir}/archive_last_modified", aws_timestamp(latest_epoch + 10))
    install_command_stubs
  end

  after do
    FileUtils.remove_entry(tempdir)
  end

  it 'passes and publishes 1 when the archive exists under the upload completion date' do
    stdout, stderr, status = run_check(tempdir)

    expect(status).to be_success, stderr
    expect(stdout).to include('Status: PASS')
    expect(archive_keys_requested(tempdir)).to eq(
      ["#{london_date(latest_epoch)}/tariff-merged-development.sql.gz"],
    )
    expect(command_log(tempdir).grep(/cloudwatch put-metric-data/).first).to include('--value 1')
  end

  it 'falls back to the previous day when a backup crosses midnight' do
    touch_flag 'archive_previous_day'

    stdout, stderr, status = run_check(tempdir)

    expect(status).to be_success, stderr
    expect(stdout).to include('Status: PASS')

    same_day, previous_day = archive_keys_requested(tempdir)
    expect(previous_day).to eq(
      "#{london_date(latest_epoch - 86_400)}/tariff-merged-development.sql.gz",
    )
    expect(Date.parse(previous_day[%r{\A\d{4}/\d{2}/\d{2}}])).to eq(
      Date.parse(same_day[%r{\A\d{4}/\d{2}/\d{2}}]) - 1,
    )
    expect(command_log(tempdir).grep(/cloudwatch put-metric-data/).first).to include('--value 1')
  end

  it 'fails and publishes 0 when both archive candidates are missing' do
    touch_flag 'archive_missing_all'

    stdout, stderr, status = run_check(tempdir)

    expect(status).to be_success, stderr
    expect(stdout).to include('Status: FAIL')
    expect(stdout).to include('are missing')
    expect(archive_keys_requested(tempdir).count).to eq(2)
    expect(command_log(tempdir).grep(/cloudwatch put-metric-data/).first).to include('--value 0')
  end

  it 'exits without publishing when an archive timestamp cannot be parsed' do
    touch_flag 'archive_unparseable'

    _stdout, stderr, status = run_check(tempdir)

    expect(status.exitstatus).to eq(2)
    expect(stderr).to include('Unable to parse archive LastModified')
    expect(command_log(tempdir).grep(/cloudwatch put-metric-data/)).to be_empty
  end

  it 'exits without publishing when S3 fails for a reason other than a missing object' do
    touch_flag 'latest_head_error'

    _stdout, stderr, status = run_check(tempdir)

    expect(status.exitstatus).to eq(5)
    expect(stderr).to include('Unable to inspect s3://trade-tariff-database-backups-test/')
    expect(command_log(tempdir).grep(/cloudwatch put-metric-data/)).to be_empty
  end
end
