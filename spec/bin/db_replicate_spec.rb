require 'fileutils'
require 'open3'
require 'tmpdir'

RSpec.describe 'bin/db-replicate' do # rubocop:disable RSpec/DescribeClass
  let(:repo_root) { File.expand_path('../..', __dir__) }
  let(:script) { File.join(repo_root, 'bin/db-replicate') }

  def write_executable(path, content)
    File.write(path, content)
    FileUtils.chmod('+x', path)
  end

  it 'does not stop services when the restore file is not a gzip stream' do
    Dir.mktmpdir do |dir|
      bin_dir = File.join(dir, 'bin')
      calls_log = File.join(dir, 'aws-calls.log')
      FileUtils.mkdir_p(bin_dir)

      write_executable(
        File.join(bin_dir, 'aws'),
        <<~BASH,
          #!/usr/bin/env bash
          echo "$*" >> "#{calls_log}"
          if [[ "$*" == *"describe-services"* ]]; then
            echo 2
          fi
        BASH
      )

      write_executable(
        File.join(bin_dir, 'curl'),
        <<~BASH,
          #!/usr/bin/env bash
          output=''
          while [[ "$#" -gt 0 ]]; do
            if [[ "$1" == "--output" ]]; then
              output="$2"
              shift 2
            else
              shift
            fi
          done

          if [[ -n "$output" ]]; then
            printf '<html>Forbidden</html>' > "$output"
          else
            printf '<html>Forbidden</html>'
          fi
        BASH
      )

      stdout, stderr, status = Open3.capture3(
        {
          'PATH' => "#{bin_dir}:#{ENV.fetch('PATH')}",
          'ENVIRONMENT' => 'staging',
          'CLUSTER_NAME' => 'trade-tariff-cluster-staging',
          'SERVICES' => 'backend-uk worker-uk',
          'DB_DUMP_USER' => 'tariff',
          'DB_DUMP_PASSWORD' => 'secret',
          'DB_DUMP_SERVER' => 'https://dumps.example.test/',
          'RESTORE_FILE' => 'tariff-merged-production.sql.gz',
          'DATABASE_URL' => 'postgres://example',
        },
        script,
      )

      calls = File.exist?(calls_log) ? File.read(calls_log) : ''

      expect(status).not_to be_success
      expect(stdout).not_to include('Stopping services')
      expect(stderr).to include('Restore file is not a gzip stream')
      expect(calls).not_to include('update-service')
    end
  end

  it 'restarts services when restore fails after services are stopped' do
    Dir.mktmpdir do |dir|
      bin_dir = File.join(dir, 'bin')
      calls_log = File.join(dir, 'aws-calls.log')
      sql_file = File.join(dir, 'dump.sql')
      gzip_file = File.join(dir, 'dump.sql.gz')
      FileUtils.mkdir_p(bin_dir)
      File.write(sql_file, 'SELECT 1;')
      system('gzip', '-c', sql_file, out: gzip_file)

      write_executable(
        File.join(bin_dir, 'aws'),
        <<~BASH,
          #!/usr/bin/env bash
          echo "$*" >> "#{calls_log}"
          if [[ "$*" == *"describe-services"* ]]; then
            echo 2
          fi
        BASH
      )

      write_executable(
        File.join(bin_dir, 'curl'),
        <<~BASH,
          #!/usr/bin/env bash
          output=''
          while [[ "$#" -gt 0 ]]; do
            if [[ "$1" == "--output" ]]; then
              output="$2"
              shift 2
            else
              shift
            fi
          done

          if [[ -n "$output" ]]; then
            head -c 2 "#{gzip_file}" > "$output"
          else
            cat "#{gzip_file}"
          fi
        BASH
      )

      write_executable(
        File.join(bin_dir, 'psql'),
        <<~BASH,
          #!/usr/bin/env bash
          cat >/dev/null
          exit 42
        BASH
      )

      _stdout, _stderr, status = Open3.capture3(
        {
          'PATH' => "#{bin_dir}:#{ENV.fetch('PATH')}",
          'ENVIRONMENT' => 'staging',
          'CLUSTER_NAME' => 'trade-tariff-cluster-staging',
          'SERVICES' => 'backend-uk worker-uk',
          'DB_DUMP_USER' => 'tariff',
          'DB_DUMP_PASSWORD' => 'secret',
          'DB_DUMP_SERVER' => 'https://dumps.example.test/',
          'RESTORE_FILE' => 'tariff-merged-production.sql.gz',
          'DATABASE_URL' => 'postgres://example',
        },
        script,
      )

      update_calls = File.readlines(calls_log).grep(/update-service/)

      expect(status.exitstatus).to eq(42)
      expect(update_calls).to contain_exactly(
        a_string_including('--service backend-uk --desired-count 0'),
        a_string_including('--service worker-uk --desired-count 0'),
        a_string_including('--service backend-uk --desired-count 2'),
        a_string_including('--service worker-uk --desired-count 2'),
      )
    end
  end
end
