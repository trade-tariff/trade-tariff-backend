begin
  require 'get_process_mem'
  MEM = GetProcessMem.new
rescue LoadError
  MEM = nil
end

class ProgressIo
  def initialize(io, total_size:, label: nil, log_every: 0.1, start_time: Time.zone.now)
    @io          = io
    @total_size  = total_size.to_f
    @bytes_read  = 0
    @label       = label || 'Reading'
    @last_report = 0.0
    @log_every   = log_every
    @start_time  = start_time
  end

  def read(*args)
    chunk = @io.read(*args)
    return nil unless chunk

    @bytes_read += chunk.bytesize
    report_progress
    chunk
  end

  def method_missing(method, *args, &block)
    @io.respond_to?(method) ? @io.send(method, *args, &block) : super
  end

  def respond_to_missing?(method, include_private = false)
    @io.respond_to?(method, include_private) || super
  end

  private

  def report_progress
    return if @total_size.zero?

    percent = (@bytes_read / @total_size) * 100
    elapsed = Time.zone.now - @start_time
    elapsed_minutes = (elapsed / 60).to_i % 60
    elapsed_hours = (elapsed / 3600).to_i % 60
    seconds_per_byte = elapsed / @bytes_read
    bytes_remaining = @total_size - @bytes_read
    eta = bytes_remaining * seconds_per_byte
    formatted_elapsed = "#{elapsed_hours}h #{elapsed_minutes}m #{elapsed.to_i % 60}s"
    eta_minutes = (eta / 60).to_i % 60
    eta_hours = (eta / 3600).to_i % 60
    formatted_eta = "#{eta_hours}h #{eta_minutes}m #{eta.to_i % 60}s"
    process_mem = MEM ? " (#{MEM.mb.round(2)} MB)" : ''

    if percent - @last_report >= @log_every
      @last_report = percent
      # rubocop:disable Rails/Output
      print "\r#{@label}: #{percent.round(1)}% complete (#{@bytes_read}/#{@total_size.to_i} bytes) [#{formatted_elapsed} elapsed, ETA: #{formatted_eta}] #{process_mem}"
      $stdout.flush
      # rubocop:enable Rails/Output
    end
  end
end
