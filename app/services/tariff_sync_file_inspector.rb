class TariffSyncFileInspector
  class Error < StandardError; end

  class << self
    def call
      require 'zip'

      update = update_from_env_filename
      raise Error, "File not found at path: #{update.file_path}" unless TariffSynchronizer::FileService.file_exists?(update.file_path)

      print_file_inspection_header(update)
      update.is_a?(TariffSynchronizer::CdsUpdate) ? inspect_cds_file(update) : inspect_taric_file(update)
    end

  private

    def update_from_env_filename
      filename = ENV['FILENAME']
      unless filename
        raise Error, 'Set FILENAME= to the full update filename (e.g. tariff_dailyExtract_v1_20240101T000000.gzip).'
      end

      TariffSynchronizer::BaseUpdate.where(filename:).first || raise(Error, "No update found with filename: #{filename}")
    end

    def print_file_inspection_header(update)
      file_size = TariffSynchronizer::FileService.file_size(update.file_path)
      $stdout.puts "=== File Inspection: #{update.filename} ===\n\n"
      $stdout.puts "State      : #{update.state}"
      $stdout.puts "Issue date : #{update.issue_date}"
      $stdout.puts "File size  : #{file_size} bytes"
      $stdout.puts
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

      $stdout.puts "Total transaction records: #{counts.values.sum}\n\n"
      if counts.any?
        print_counts_table('Record Type', counts)
      else
        $stdout.puts '(No records found - file may use a different XML structure)'
      end
    end

    def print_counts(total_label, column_label, counts)
      $stdout.puts "#{total_label}: #{counts.values.sum}\n\n"
      print_counts_table(column_label, counts)
    end

    def print_counts_table(column_label, counts)
      $stdout.puts sprintf('%-55s %6s', column_label, 'Count')
      $stdout.puts '-' * 63
      counts.sort_by { |_, value| -value }.each do |key, count|
        $stdout.puts sprintf('%-55s %6d', key, count)
      end
    end
  end
end
