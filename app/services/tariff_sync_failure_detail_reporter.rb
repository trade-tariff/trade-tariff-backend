class TariffSyncFailureDetailReporter
  class Error < StandardError; end

  class << self
    def call
      update = update_from_env_filename
      print_header(update)
      print_exception(update)
      print_presence_errors(update)
      print_previous_import_counts(update)
    end

  private

    def update_from_env_filename
      filename = ENV['FILENAME']
      unless filename
        raise Error, 'Set FILENAME= to the full update filename (e.g. tariff_dailyExtract_v1_20240101T000000.gzip).'
      end

      TariffSynchronizer::BaseUpdate.where(filename:).first || raise(Error, "No update found with filename: #{filename}")
    end

    def print_header(update)
      service = update.is_a?(TariffSynchronizer::CdsUpdate) ? 'UK (CDS)' : 'XI (TARIC)'
      $stdout.puts "=== Failure Detail: #{update.filename} ===\n\n"
      $stdout.puts "Service    : #{service}"
      $stdout.puts "State      : #{update.state}"
      $stdout.puts "Issue date : #{update.issue_date}"
      $stdout.puts "File size  : #{update.filesize ? "#{update.filesize} bytes" : 'unknown'}"
      $stdout.puts "Created at : #{update.created_at}"
      $stdout.puts "Updated at : #{update.updated_at}"
    end

    def print_exception(update)
      return if update.exception_class.blank?

      $stdout.puts "\n=== Exception ===\n\n"
      $stdout.puts update.exception_class
      $stdout.puts
      print_exception_backtrace(update)
      print_exception_queries(update)
    end

    def print_exception_backtrace(update)
      return if update.exception_backtrace.blank?

      $stdout.puts "=== Backtrace (first 20 lines) ===\n\n"
      update.exception_backtrace.split("\n").first(20).each { |line| $stdout.puts line }
    end

    def print_exception_queries(update)
      return if update.exception_queries.blank?

      $stdout.puts "\n=== Last SQL Queries ===\n\n"
      $stdout.puts update.exception_queries
    end

    def print_presence_errors(update)
      presence_errors = update.presence_errors
      return if presence_errors.empty?

      $stdout.puts "\n=== Presence Errors (#{presence_errors.count} total, showing first 10) ===\n\n"
      presence_errors.first(10).each_with_index do |error, index|
        $stdout.puts "#{index + 1}. #{error.model_name}"
        $stdout.puts error.details.inspect
        $stdout.puts
      end
    end

    def print_previous_import_counts(update)
      return if update.inserts.blank?

      $stdout.puts "\n=== Previous Import Operation Counts ===\n\n"
      $stdout.puts JSON.pretty_generate(JSON.parse(update.inserts))
    rescue JSON::ParserError
      $stdout.puts update.inserts
    end
  end
end
