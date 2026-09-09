require 'json'
require 'securerandom'
require 'time'
require 'puma/plugin'

# Kept identical in trade-tariff-frontend and trade-tariff-backend. No Rails,
# network calls or request hooks: only the Puma master's cached worker stats.
class PumaMetrics
  INTERVAL = 10
  MAX_SAMPLE_BYTES = 4096
  WORKER_METRICS = %w[BusyThreads AvailableThreads MaxThreads Backlog BacklogMax Utilization].freeze
  COVERAGE_METRICS = %w[ExpectedWorkers ReportingWorkers StaleWorkers UnreadyWorkers SaturatedWorkers].freeze

  def initialize(stats:, environment:, service:, output: $stdout, stale_after: 30)
    @stats = stats
    @environment = environment
    @service = service
    @output = output
    @stale_after = stale_after
    @collector_id = SecureRandom.uuid
    @stop = Queue.new
  end

  def run
    loop do
      @stop.pop(timeout: INTERVAL)
      break if @stop.closed?

      sample
    end
  end

  def stop
    # Puma invokes shutdown callbacks from signal traps. Queue#close is safe
    # there, unlike Mutex#synchronize, and wakes the sleeping sampler.
    @stop.close
  end

  # The master does not load Rails in non-preloaded deployments.
  def sample(now: Process.clock_gettime(Process::CLOCK_REALTIME))
    now = now.to_f
    snapshot = @stats.call
    workers = snapshot.fetch(:worker_status) do
      [{ pid: Process.pid, index: 0, booted: true, last_checkin: now, last_status: snapshot }]
    end
    payload = build_payload(workers, snapshot.fetch(:workers, 1), now)
    line = "#{JSON.generate(payload)}\n"
    return false if line.bytesize > MAX_SAMPLE_BYTES

    # Never wait on logging backpressure and never retry/buffer stale samples.
    @output.write_nonblock(line, exception: false) == line.bytesize
  rescue StandardError
    # Telemetry failure must not interrupt Puma. Missing coverage is visible on
    # the dashboard; deliberately avoid recursively writing to a failing logger.
    false
  end

private

  def build_payload(workers, expected, now)
    stale = 0
    unready = 0
    samples = workers.filter_map do |worker|
      if !worker[:booted] || !valid_pool?(worker[:last_status])
        unready += 1
        next
      end
      age = checkin_age(worker[:last_checkin], now)
      unless age
        unready += 1
        next
      end
      if age.negative? || age > @stale_after
        stale += 1
        next
      end
      worker_sample(worker, age)
    end

    payload = {
      event: 'puma.metrics',
      Environment: @environment,
      Service: @service,
      collector_id: @collector_id,
      workers: samples,
      ExpectedWorkers: expected,
      ReportingWorkers: samples.size,
      StaleWorkers: stale,
      UnreadyWorkers: unready,
      SaturatedWorkers: samples.count { |s| s[:AvailableThreads].zero? },
    }
    unless samples.empty?
      WORKER_METRICS.each { |name| payload[name] = samples.map { |s| s.fetch(name.to_sym) } }
      payload.merge!(
        task_busy_threads: samples.sum { |s| s[:BusyThreads] },
        task_available_threads: samples.sum { |s| s[:AvailableThreads] },
        task_max_threads: samples.sum { |s| s[:MaxThreads] },
        task_backlog: samples.sum { |s| s[:Backlog] },
      )
    end
    names = COVERAGE_METRICS + (samples.empty? ? [] : WORKER_METRICS)
    payload[:_aws] = {
      Timestamp: (now.to_f * 1000).to_i,
      CloudWatchMetrics: [{
        Namespace: 'TradeTariff/Puma',
        Dimensions: [%w[Environment Service]],
        Metrics: names.map { |name| { Name: name, Unit: name == 'Utilization' ? 'Percent' : 'Count', StorageResolution: 1 } },
      }],
    }
    payload
  end

  def checkin_age(timestamp, now)
    now - (timestamp.is_a?(Numeric) ? timestamp : Time.iso8601(timestamp).to_f)
  rescue ArgumentError, TypeError
    nil
  end

  def valid_pool?(pool)
    return false unless pool.is_a?(Hash)

    max = pool[:max_threads]
    available = pool[:pool_capacity]
    backlog = pool[:backlog]
    max.is_a?(Integer) && max.positive? && available.is_a?(Integer) &&
      available.between?(0, max) && backlog.is_a?(Integer) && backlog >= 0
  end

  def worker_sample(worker, age)
    pool = worker.fetch(:last_status)
    max = pool.fetch(:max_threads)
    available = pool.fetch(:pool_capacity)
    # Puma 8's busy_threads includes backlog; running means spawned threads.
    busy = max - available
    {
      pid: worker[:pid],
      index: worker[:index],
      checkin_age_seconds: age.round(3),
      BusyThreads: busy,
      AvailableThreads: available,
      MaxThreads: max,
      Backlog: pool.fetch(:backlog),
      BacklogMax: pool.fetch(:backlog_max, pool.fetch(:backlog)),
      Utilization: (100.0 * busy / max).round(2),
    }
  end

  class Plugin < Puma::Plugin
    def start(launcher)
      reporter = PumaMetrics.new(
        stats: -> { launcher.stats },
        environment: ENV.fetch('PUMA_METRICS_ENVIRONMENT', ENV.fetch('RAILS_ENV', 'development')),
        service: ENV.fetch('PUMA_METRICS_SERVICE'),
        stale_after: [30, launcher.options.fetch(:worker_check_interval, 5) * 3].max,
      )
      launcher.events.after_stopped { reporter.stop }
      launcher.events.before_restart { reporter.stop }
      in_background { reporter.run }
    end
  end
end
