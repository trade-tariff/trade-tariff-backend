# Diagnostic and recovery rake tasks for tariff synchronisation.
#
# These tasks are intended to help developers understand and recover from
# sync failures without needing ad-hoc console work.
#
# Usage:
#   rake tariff:sync:status
#   rake tariff:sync:failures
#   rake tariff:sync:failure_detail FILENAME=tariff_dailyExtract_v1_20240101T000000.gzip
#   rake tariff:sync:inspect_file   FILENAME=tariff_dailyExtract_v1_20240101T000000.gzip
#   rake tariff:sync:reset_failed
#   rake tariff:sync:force_apply    FILENAME=tariff_dailyExtract_v1_20240101T000000.gzip CONFIRM=yes

module TariffSyncToolingTasks
module_function

  def status
    update_classes.each do |label, klass|
      puts "=== #{label} ===\n\n"
      print_update_status(klass)
      puts
    end
  end

  def update_classes
    {
      'UK (CDS)' => TariffSynchronizer::CdsUpdate,
      'XI (TARIC)' => TariffSynchronizer::TaricUpdate,
    }
  end

  def print_update_status(klass)
    last_applied = klass.most_recent_applied
    puts "  Last applied : #{last_applied ? "#{last_applied.issue_date}  #{last_applied.filename}" : 'none'}"
    print_update_list('Pending', klass.pending.ascending.all)
    print_update_list('Failed', klass.failed.ascending.all, include_error: true)
    print_update_list('Missing', klass.missing.ascending.all)
    puts "  Sequence     : #{klass.correct_filename_sequence? ? 'OK' : 'INVALID - pipeline is blocked'}"
  end

  def print_update_list(label, updates, include_error: false)
    puts "  #{label.ljust(12)} : #{updates.count}"
    updates.each do |update|
      puts "    - #{update.issue_date}  #{update.filename}"
      puts "      #{update.exception_class}" if include_error && update.exception_class.present?
    end
  end

  def failures
    failed = TariffSynchronizer::BaseUpdate.failed.ascending.all
    return puts 'No failed updates.' if failed.empty?

    puts "#{failed.count} failed update(s):\n\n"
    failed.each { |update| print_failure_summary(update) }
    puts "Run 'rake tariff:sync:failure_detail FILENAME=<filename>' for full details."
  end

  def print_failure_summary(update)
    service = update.is_a?(TariffSynchronizer::CdsUpdate) ? 'UK/CDS' : 'XI/TARIC'
    puts update.filename
    puts "  Service         : #{service}"
    puts "  Issue date      : #{update.issue_date}"
    puts "  Updated at      : #{update.updated_at}"
    puts "  Error           : #{update.exception_class}" if update.exception_class.present?

    presence_count = update.presence_errors.count
    puts "  Presence errors : #{presence_count}" if presence_count.positive?
    puts
  end

  def failure_detail
    update = update_from_env_filename
    print_failure_detail_header(update)
    print_exception_detail(update)
    print_presence_errors(update)
    print_previous_import_counts(update)
  end

  def update_from_env_filename
    filename = ENV['FILENAME']
    abort 'Set FILENAME= to the full update filename (e.g. tariff_dailyExtract_v1_20240101T000000.gzip).' unless filename

    TariffSynchronizer::BaseUpdate.where(filename:).first || abort("No update found with filename: #{filename}")
  end

  def print_failure_detail_header(update)
    service = update.is_a?(TariffSynchronizer::CdsUpdate) ? 'UK (CDS)' : 'XI (TARIC)'
    puts "=== Failure Detail: #{update.filename} ===\n\n"
    puts "Service    : #{service}"
    puts "State      : #{update.state}"
    puts "Issue date : #{update.issue_date}"
    puts "File size  : #{update.filesize ? "#{update.filesize} bytes" : 'unknown'}"
    puts "Created at : #{update.created_at}"
    puts "Updated at : #{update.updated_at}"
  end

  def print_exception_detail(update)
    return if update.exception_class.blank?

    puts "\n=== Exception ===\n\n"
    puts update.exception_class
    puts
    print_exception_backtrace(update)
    print_exception_queries(update)
  end

  def print_exception_backtrace(update)
    return if update.exception_backtrace.blank?

    puts "=== Backtrace (first 20 lines) ===\n\n"
    update.exception_backtrace.split("\n").first(20).each { |line| puts line }
  end

  def print_exception_queries(update)
    return if update.exception_queries.blank?

    puts "\n=== Last SQL Queries ===\n\n"
    puts update.exception_queries
  end

  def print_presence_errors(update)
    presence_errors = update.presence_errors
    return if presence_errors.empty?

    puts "\n=== Presence Errors (#{presence_errors.count} total, showing first 10) ===\n\n"
    presence_errors.first(10).each_with_index do |error, index|
      puts "#{index + 1}. #{error.model_name}"
      puts error.details.inspect
      puts
    end
  end

  def print_previous_import_counts(update)
    return if update.inserts.blank?

    puts "\n=== Previous Import Operation Counts ===\n\n"
    puts JSON.pretty_generate(JSON.parse(update.inserts))
  rescue JSON::ParserError
    puts update.inserts
  end

  def inspect_file
    require 'zip'

    update = update_from_env_filename
    abort "File not found at path: #{update.file_path}" unless TariffSynchronizer::FileService.file_exists?(update.file_path)

    print_file_inspection_header(update)
    update.is_a?(TariffSynchronizer::CdsUpdate) ? inspect_cds_file(update) : inspect_taric_file(update)
  end

  def print_file_inspection_header(update)
    file_size = TariffSynchronizer::FileService.file_size(update.file_path)
    puts "=== File Inspection: #{update.filename} ===\n\n"
    puts "State      : #{update.state}"
    puts "Issue date : #{update.issue_date}"
    puts "File size  : #{file_size} bytes"
    puts
  end

  def inspect_cds_file(update)
    counts = Hash.new(0)
    counting_handler = Object.new
    counting_handler.define_singleton_method(:process_xml_node) { |key, _hash| counts[key] += 1 }

    zip_io = TariffSynchronizer::FileService.file_as_stringio(update)
    Zip::File.open_buffer(zip_io) do |archive|
      archive.entries.each do |entry|
        CdsImporter::XmlParser::Reader.new(entry.get_input_stream, counting_handler).parse
      end
    end

    print_counts('Total entity records', 'Entity', counts)
  end

  def inspect_taric_file(update)
    xml_content = TariffSynchronizer::FileService.get(update.file_path)
    doc = Nokogiri::XML(xml_content)
    counts = Hash.new(0)
    doc.xpath('//record').each do |record|
      type = record.xpath('./*[1]').first&.name || 'unknown'
      counts[type] += 1
    end

    return puts '(No records found - file may use a different XML structure)' if counts.empty?

    print_counts('Total transaction records', 'Record Type', counts)
  end

  def print_counts(total_label, column_label, counts)
    puts "#{total_label}: #{counts.values.sum}\n\n"
    puts sprintf('%-55s %6s', column_label, 'Count')
    puts '-' * 63
    counts.sort_by { |_, value| -value }.each do |key, count|
      puts sprintf('%-55s %6d', key, count)
    end
  end

  def reset_failed
    failed = TariffSynchronizer::BaseUpdate.failed.all
    return puts 'No failed updates to reset.' if failed.empty?

    failed.each { |update| reset_failed_update(update) }
    puts "\n#{failed.count} update(s) reset to pending."
    puts "Run 'rake tariff:sync:apply' to retry."
  end

  def reset_failed_update(update)
    update.update(
      state: TariffSynchronizer::BaseUpdate::PENDING_STATE,
      exception_class: nil,
      exception_backtrace: nil,
      exception_queries: nil,
    )
    puts "Reset: #{update.filename}"
  end

  def force_apply
    filename = ENV['FILENAME']
    abort 'Set FILENAME= to the full update filename.' unless filename

    confirm_force_apply!(filename)
    update = TariffSynchronizer::BaseUpdate.where(filename:).first
    abort "No update found with filename: #{filename}" unless update
    abort "Update '#{filename}' is not in failed state (state: #{update.state})." unless update.failed?

    update.mark_as_applied
    puts "#{filename} marked as applied."
    puts "Run 'rake tariff:sync:apply' to continue with any remaining pending updates."
  end

  def confirm_force_apply!(filename)
    return if ENV['CONFIRM'] == 'yes'

    warn <<~WARNING
      WARNING: This marks an update as applied WITHOUT importing its data.
      Any changes in this file will be absent from the tariff database.
      Only use this if you have applied the changes manually, or confirmed they are safe to skip.

      To confirm: rake tariff:sync:force_apply FILENAME=#{filename} CONFIRM=yes
    WARNING
    exit 1
  end
end

namespace :tariff do
  namespace :sync do
    desc 'Show current synchronisation status for UK (CDS) and XI (TARIC) services'
    task(status: %i[environment class_eager_load]) { TariffSyncToolingTasks.status }
    desc 'List all failed updates with error summary'
    task(failures: %i[environment class_eager_load]) { TariffSyncToolingTasks.failures }
    desc 'Show full failure detail for one update. Set FILENAME= to the full filename.'
    task(failure_detail: %i[environment class_eager_load]) { TariffSyncToolingTasks.failure_detail }
    desc 'Parse a file and summarise its contents without applying. Set FILENAME= to the full filename.'
    task(inspect_file: %i[environment class_eager_load]) { TariffSyncToolingTasks.inspect_file }
    desc 'Reset all failed updates to pending so they can be retried after a fix'
    task(reset_failed: %i[environment class_eager_load]) { TariffSyncToolingTasks.reset_failed }
    desc 'DANGER: Mark a failed update as applied without importing its data. Set FILENAME= and CONFIRM=yes.'
    task(force_apply: %i[environment class_eager_load]) { TariffSyncToolingTasks.force_apply }
  end
end
