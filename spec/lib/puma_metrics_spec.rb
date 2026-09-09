require 'rspec'
require 'json'
require 'stringio'
require_relative '../../lib/puma_metrics'

RSpec.describe PumaMetrics do
  subject(:reporter) do
    described_class.new(stats: -> { stats }, environment: 'test', service: 'backend-uk', output: output)
  end

  let(:output) { instance_double(IO) }
  let(:now) { Time.utc(2026, 9, 9, 12) }
  let(:worker) do
    {
      pid: 123,
      index: 0,
      booted: true,
      last_checkin: now.iso8601,
      last_status: { max_threads: 6, pool_capacity: 2, busy_threads: 7, backlog: 3, backlog_max: 5, running: 6 },
    }
  end
  let(:stats) { { workers: 1, worker_status: [worker] } }
  let(:lines) { [] }

  before do
    allow(output).to receive(:write_nonblock) do |line, **|
      lines << JSON.parse(line)
      line.bytesize
    end
  end

  describe '#sample' do
    it 'separates executing and queued work' do
      reporter.sample(now: now)
      expect(lines.last).to include('BusyThreads' => [4], 'AvailableThreads' => [2], 'Backlog' => [3], 'BacklogMax' => [5], 'MaxThreads' => [6])
    end

    it 'reports the per-worker utilisation' do
      reporter.sample(now: now)
      expect(lines.last.fetch('Utilization').first).to be_within(0.01).of(66.67)
    end

    it 'bounds custom metric dimensions' do
      reporter.sample(now: now)
      expect(lines.last.dig('_aws', 'CloudWatchMetrics', 0, 'Dimensions')).to eq([%w[Environment Service]])
    end

    it 'uses high-resolution EMF metrics' do
      reporter.sample(now: now)
      expect(lines.last.dig('_aws', 'CloudWatchMetrics', 0, 'Metrics')).to all(include('StorageResolution' => 1))
    end

    it 'keeps identity outside dimensions' do
      reporter.sample(now: now)
      expect(lines.last).to include('collector_id' => a_kind_of(String), 'workers' => [include('pid' => 123, 'index' => 0)])
    end

    it 'reports coverage and task totals' do
      reporter.sample(now: now)
      expect(lines.last).to include('ReportingWorkers' => 1, 'ExpectedWorkers' => 1, 'StaleWorkers' => 0, 'task_busy_threads' => 4, 'task_available_threads' => 2, 'task_backlog' => 3)
    end

    context 'with multiple workers' do
      let(:stats) { { workers: 2, worker_status: [worker, worker.merge(pid: 456, index: 1, last_status: worker[:last_status].merge(pool_capacity: 0))] } }

      it 'retains individual worker samples' do
        reporter.sample(now: now)
        expect(lines.last).to include('BusyThreads' => [4, 6], 'AvailableThreads' => [2, 0], 'SaturatedWorkers' => 1, 'task_busy_threads' => 10)
      end
    end

    context 'with a stale worker' do
      let(:worker) { super().merge(last_checkin: (now - 31).iso8601) }

      it 'reports missing coverage not idle', :aggregate_failures do
        reporter.sample(now: now)
        expect(lines.last).to include('ReportingWorkers' => 0, 'StaleWorkers' => 1)
        expect(lines.last).not_to have_key('AvailableThreads')
        expect(lines.last).not_to have_key('task_available_threads')
      end
    end

    context 'with a missing check-in' do
      let(:stats) { { workers: 2, worker_status: [worker, worker.merge(pid: 456, last_checkin: nil)] } }

      it 'still reports the healthy worker' do
        reporter.sample(now: now)
        expect(lines.last).to include('ReportingWorkers' => 1, 'UnreadyWorkers' => 1, 'BusyThreads' => [4])
      end
    end

    context 'with an oversized snapshot' do
      let(:stats) { { workers: 100, worker_status: Array.new(100) { |i| worker.merge(pid: i, index: i) } } }

      it 'drops rather than splits the event', :aggregate_failures do
        expect(reporter.sample(now: now)).to be(false)
        expect(output).not_to have_received(:write_nonblock)
      end
    end

    context 'with an unbooted worker' do
      let(:worker) { super().merge(booted: false, last_status: {}) }

      it 'does not invent capacity' do
        reporter.sample(now: now)
        expect(lines.last).to include('ReportingWorkers' => 0, 'UnreadyWorkers' => 1)
      end
    end

    context 'with invalid pool statistics' do
      let(:worker) { super().tap { |value| value[:last_status][:pool_capacity] = 7 } }

      it 'omits the invalid worker' do
        reporter.sample(now: now)
        expect(lines.last).to include('ReportingWorkers' => 0, 'UnreadyWorkers' => 1)
      end
    end

    context 'with single mode' do
      let(:stats) { worker[:last_status] }

      it 'samples the single process' do
        reporter.sample(now: now)
        expect(lines.last).to include('ReportingWorkers' => 1, 'BusyThreads' => [4])
      end
    end

    context 'when the single server is unready' do
      let(:stats) { {} }

      it 'reports missing coverage' do
        reporter.sample(now: now)
        expect(lines.last).to include('ReportingWorkers' => 0, 'UnreadyWorkers' => 1)
      end
    end

    context 'when stdout is backpressured' do
      before { allow(output).to receive(:write_nonblock).and_return(:wait_writable) }

      it 'drops the sample without waiting' do
        expect(reporter.sample(now: now)).to be(false)
      end
    end

    context 'when stdout writes a partial line' do
      before { allow(output).to receive(:write_nonblock).and_return(5) }

      it 'drops partial writes without retry', :aggregate_failures do
        expect(reporter.sample(now: now)).to be(false)
        expect(output).to have_received(:write_nonblock).once
      end
    end

    context 'when stdout is closed' do
      before { allow(output).to receive(:write_nonblock).and_raise(IOError) }

      it 'does not propagate the failure' do
        expect(reporter.sample(now: now)).to be(false)
      end
    end

    context 'when stats collection fails' do
      let(:stats) { raise 'stats unavailable' }

      it 'does not propagate the failure' do
        expect(reporter.sample(now: now)).to be(false)
      end
    end

    it 'recovers on the next sample' do
      allow(output).to receive(:write_nonblock).and_raise(IOError)
      reporter.sample(now: now)
      allow(output).to receive(:write_nonblock) { |line, **| line.bytesize }
      expect(reporter.sample(now: now)).to be(true)
    end
  end

  describe '#stop' do
    it 'wakes the sleeping reporter' do
      thread = Thread.new { reporter.run }
      reporter.stop
      expect(thread.join(1)).to eq(thread)
    ensure
      thread&.kill
    end
  end
end
