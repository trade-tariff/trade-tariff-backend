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

namespace :tariff do
  namespace :sync do
    desc 'Show current synchronisation status for UK (CDS) and XI (TARIC) services'
    task status: %i[environment class_eager_load] do
      {
        'UK (CDS)' => TariffSynchronizer::CdsUpdate,
        'XI (TARIC)' => TariffSynchronizer::TaricUpdate,
      }.each do |label, klass|
        puts "=== #{label} ===\n\n"

        last_applied = klass.most_recent_applied
        puts "  Last applied : #{last_applied ? "#{last_applied.issue_date}  #{last_applied.filename}" : 'none'}"

        pending = klass.pending.ascending.all
        puts "  Pending      : #{pending.count}"
        pending.each { |u| puts "    - #{u.issue_date}  #{u.filename}" }

        failed = klass.failed.ascending.all
        puts "  Failed       : #{failed.count}"
        failed.each do |u|
          puts "    - #{u.issue_date}  #{u.filename}"
          puts "      #{u.exception_class}" if u.exception_class.present?
        end

        missing = klass.missing.ascending.all
        puts "  Missing      : #{missing.count}"
        missing.each { |u| puts "    - #{u.issue_date}  #{u.filename}" }

        sequence_ok = klass.correct_filename_sequence?
        puts "  Sequence     : #{sequence_ok ? 'OK' : 'INVALID - pipeline is blocked'}"

        puts
      end
    end

    desc 'List all failed updates with error summary'
    task failures: %i[environment class_eager_load] do
      failed = TariffSynchronizer::BaseUpdate.failed.ascending.all

      if failed.empty?
        puts 'No failed updates.'
      else
        puts "#{failed.count} failed update(s):\n\n"

        failed.each do |update|
          service = update.is_a?(TariffSynchronizer::CdsUpdate) ? 'UK/CDS' : 'XI/TARIC'

          puts update.filename
          puts "  Service         : #{service}"
          puts "  Issue date      : #{update.issue_date}"
          puts "  Updated at      : #{update.updated_at}"
          puts "  Error           : #{update.exception_class}" if update.exception_class.present?

          cds_count = update.cds_errors.count
          puts "  CDS errors      : #{cds_count}" if cds_count.positive?

          presence_count = update.presence_errors.count
          puts "  Presence errors : #{presence_count}" if presence_count.positive?

          puts
        end

        puts "Run 'rake tariff:sync:failure_detail FILENAME=<filename>' for full details."
      end
    end

    desc 'Show full failure detail for one update. Set FILENAME= to the full filename.'
    task failure_detail: %i[environment class_eager_load] do
      filename = ENV['FILENAME']
      abort 'Set FILENAME= to the full update filename (e.g. tariff_dailyExtract_v1_20240101T000000.gzip).' unless filename

      update = TariffSynchronizer::BaseUpdate.where(filename:).first
      abort "No update found with filename: #{filename}" unless update

      service = update.is_a?(TariffSynchronizer::CdsUpdate) ? 'UK (CDS)' : 'XI (TARIC)'

      puts "=== Failure Detail: #{update.filename} ===\n\n"
      puts "Service    : #{service}"
      puts "State      : #{update.state}"
      puts "Issue date : #{update.issue_date}"
      puts "File size  : #{update.filesize ? "#{update.filesize} bytes" : 'unknown'}"
      puts "Created at : #{update.created_at}"
      puts "Updated at : #{update.updated_at}"

      if update.exception_class.present?
        puts "\n=== Exception ===\n\n"
        puts update.exception_class
        puts

        if update.exception_backtrace.present?
          puts "=== Backtrace (first 20 lines) ===\n\n"
          update.exception_backtrace.split("\n").first(20).each { |line| puts line }
        end

        if update.exception_queries.present?
          puts "\n=== Last SQL Queries ===\n\n"
          puts update.exception_queries
        end
      end

      cds_errors = update.cds_errors.all
      if cds_errors.any?
        puts "\n=== CDS Record Errors (#{cds_errors.count} total, showing first 10) ===\n\n"
        cds_errors.first(10).each_with_index do |err, i|
          puts "#{i + 1}. #{err.model_name}"
          begin
            puts JSON.pretty_generate(err.details)
          rescue JSON::GeneratorError
            puts err.details.inspect
          end
          puts
        end
      end

      presence_errors = update.presence_errors.all
      if presence_errors.any?
        puts "\n=== Presence Errors (#{presence_errors.count} total, showing first 10) ===\n\n"
        presence_errors.first(10).each_with_index do |err, i|
          puts "#{i + 1}. #{err.model_name}"
          puts err.details.inspect
          puts
        end
      end

      if update.inserts.present?
        puts "\n=== Previous Import Operation Counts ===\n\n"
        begin
          puts JSON.pretty_generate(JSON.parse(update.inserts))
        rescue JSON::ParserError
          puts update.inserts
        end
      end
    end

    desc 'Parse a file and summarise its contents without applying. Set FILENAME= to the full filename.'
    task inspect_file: %i[environment class_eager_load] do
      require 'zip'

      filename = ENV['FILENAME']
      abort 'Set FILENAME= to the full update filename.' unless filename

      update = TariffSynchronizer::BaseUpdate.where(filename:).first
      abort "No update found with filename: #{filename}" unless update

      unless TariffSynchronizer::FileService.file_exists?(update.file_path)
        abort "File not found at path: #{update.file_path}"
      end

      file_size = TariffSynchronizer::FileService.file_size(update.file_path)

      puts "=== File Inspection: #{update.filename} ===\n\n"
      puts "State      : #{update.state}"
      puts "Issue date : #{update.issue_date}"
      puts "File size  : #{file_size} bytes"
      puts

      if update.is_a?(TariffSynchronizer::CdsUpdate)
        counts = Hash.new(0)

        counting_handler = Object.new
        counting_handler.define_singleton_method(:process_xml_node) { |key, _hash| counts[key] += 1 }

        zip_io = TariffSynchronizer::FileService.file_as_stringio(update)
        Zip::File.open_buffer(zip_io) do |archive|
          archive.entries.each do |entry|
            CdsImporter::XmlParser::Reader.new(entry.get_input_stream, counting_handler).parse
          end
        end

        total = counts.values.sum
        puts "Total entity records: #{total}\n\n"
        puts sprintf('%-55s %6s', 'Entity', 'Count')
        puts '-' * 63
        counts.sort_by { |_, v| -v }.each do |entity, count|
          puts sprintf('%-55s %6d', entity, count)
        end
      else
        xml_content = TariffSynchronizer::FileService.get(update.file_path)
        doc = Nokogiri::XML(xml_content)

        counts = Hash.new(0)
        doc.xpath('//record').each do |record|
          type = record.xpath('./*[1]').first&.name || 'unknown'
          counts[type] += 1
        end

        total = counts.values.sum
        puts "Total transaction records: #{total}\n\n"

        if counts.any?
          puts sprintf('%-55s %6s', 'Record Type', 'Count')
          puts '-' * 63
          counts.sort_by { |_, v| -v }.each do |type, count|
            puts sprintf('%-55s %6d', type, count)
          end
        else
          puts '(No records found - file may use a different XML structure)'
        end
      end
    end

    desc 'Reset all failed updates to pending so they can be retried after a fix'
    task reset_failed: %i[environment class_eager_load] do
      failed = TariffSynchronizer::BaseUpdate.failed.all

      if failed.empty?
        puts 'No failed updates to reset.'
      else
        failed.each do |update|
          update.update(
            state: TariffSynchronizer::BaseUpdate::PENDING_STATE,
            exception_class: nil,
            exception_backtrace: nil,
            exception_queries: nil,
          )
          puts "Reset: #{update.filename}"
        end
        puts "\n#{failed.count} update(s) reset to pending."
        puts "Run 'rake tariff:sync:apply' to retry."
      end
    end

    desc 'DANGER: Mark a failed update as applied without importing its data. Set FILENAME= and CONFIRM=yes.'
    task force_apply: %i[environment class_eager_load] do
      filename = ENV['FILENAME']
      confirm  = ENV['CONFIRM']

      abort 'Set FILENAME= to the full update filename.' unless filename

      unless confirm == 'yes'
        warn <<~WARNING
          WARNING: This marks an update as applied WITHOUT importing its data.
          Any changes in this file will be absent from the tariff database.
          Only use this if you have applied the changes manually, or confirmed they are safe to skip.

          To confirm: rake tariff:sync:force_apply FILENAME=#{filename} CONFIRM=yes
        WARNING
        exit 1
      end

      update = TariffSynchronizer::BaseUpdate.where(filename:).first
      abort "No update found with filename: #{filename}" unless update

      unless update.failed?
        abort "Update '#{filename}' is not in failed state (state: #{update.state})."
      end

      update.mark_as_applied
      puts "#{filename} marked as applied."
      puts "Run 'rake tariff:sync:apply' to continue with any remaining pending updates."
    end
  end
end
