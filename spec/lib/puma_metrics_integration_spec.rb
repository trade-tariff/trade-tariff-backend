require 'rspec'
require 'json'
require 'socket'
require 'tmpdir'
require 'timeout'
require 'rbconfig'
require 'open3'
require_relative '../../lib/puma_metrics'

RSpec.describe PumaMetrics do
  it 'does not load the disabled reporter' do
    config = File.expand_path('../../config/puma.rb', __dir__)
    script = <<~RUBY
      require 'puma'
      require 'puma/configuration'
      Puma::Configuration.new(config_files: [ARGV.fetch(0)]).load
      abort 'disabled reporter was loaded' if defined?(PumaMetrics)
    RUBY
    output, status = Open3.capture2e(
      { 'PUMA_METRICS_ENABLED' => nil, 'RAILS_ENV' => 'test', 'SSL_CERT_PEM' => nil, 'SSL_KEY_PEM' => nil },
      RbConfig.ruby, '-e', script, config
    )
    expect(status).to be_success, output
  end

  [0, 1].each do |worker_count|
    context "with #{worker_count} cluster workers" do
      it 'reports saturation and shuts down', :aggregate_failures do
        Dir.mktmpdir('puma-metrics') do |dir|
          socket_path = File.join(dir, 'puma.sock')
          started = File.join(dir, 'request-started')
          release = File.join(dir, 'release')
          config = File.join(dir, 'puma.rb')
          application_config = File.expand_path('../../config/puma.rb', __dir__)
          File.write(config, <<~RUBY)
            instance_eval(File.read(#{application_config.inspect}), #{application_config.inspect})
            workers #{worker_count}
            threads 1, 1
            worker_check_interval 1
            raise_exception_on_sigterm false
            bind #{"unix://#{socket_path}".inspect}
            app ->(_env) {
              File.write(#{started.inspect}, 'started')
              sleep 0.01 until File.exist?(#{release.inspect})
              [200, { 'content-type' => 'text/plain' }, ['ok']]
            }
          RUBY
          reader, writer = IO.pipe
          pid = Process.spawn(
            { 'PUMA_METRICS_ENABLED' => 'true', 'PUMA_METRICS_SERVICE' => 'test-app', 'PUMA_METRICS_ENVIRONMENT' => 'test', 'RAILS_ENV' => 'test', 'SSL_CERT_PEM' => nil, 'SSL_KEY_PEM' => nil },
            RbConfig.ruby, '-S', 'puma', '-C', config,
            out: writer, err: writer, pgroup: true
          )
          writer.close
          Timeout.timeout(15) { sleep 0.01 until File.socket?(socket_path) }
          client = UNIXSocket.new(socket_path)
          client.write("GET /slow HTTP/1.0\r\n\r\n")
          Timeout.timeout(15) { sleep 0.01 until File.exist?(started) }
          sample = Timeout.timeout(25) do
            loop do
              line = reader.gets
              raise 'Puma exited before reporting' unless line
              next unless line.start_with?('{')

              parsed = JSON.parse(line)
              break parsed if parsed['BusyThreads'] == [1]
            end
          end
          expect(sample).to include('AvailableThreads' => [0], 'MaxThreads' => [1], 'SaturatedWorkers' => 1, 'ReportingWorkers' => 1)
          File.write(release, 'release')
          expect(Timeout.timeout(5) { client.read }).to include('200 OK')
          Process.kill('TERM', pid)
          _, status = Timeout.timeout(10) { Process.wait2(pid) }
          expect(status).to be_success, reader.read
        rescue Timeout::Error => e
          raise "#{e.message}: #{reader&.read_nonblock(16_384, exception: false)}"
        ensure
          client&.close
          reader&.close
          writer&.close unless writer&.closed?
          begin
            Process.kill('KILL', -pid) if pid
          rescue Errno::ESRCH
            nil
          end
          begin
            Process.wait(pid) if pid
          rescue Errno::ECHILD
            nil
          end
        end
      end
    end
  end
end
