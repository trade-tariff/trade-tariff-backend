require 'csv'

module TariffKnowledge
  # Imports the analysts' spreadsheet (as CSV text) into synthetic ATaRs.
  #
  # It behaves like DescriptionIntercepts::TemplateImporter:
  # - A record is matched on its real user search (trimmed, case-insensitive), so
  #   importing a newer version of the sheet updates existing rows and adds new ones.
  # - It is all-or-nothing. Every row is checked first. If any row has an error,
  #   nothing is saved and every error is returned with its line number.
  # - Rows are saved through the model, so has_paper_trail records each change.
  #
  # A row that is not finished (status is not "Done", or the description or the
  # commodity code is empty) is skipped and counted. It is not an error.
  class SyntheticAtarImporter
    Result = Data.define(:created_count, :updated_count, :unchanged_count, :skipped_count, :summary_errors, :row_errors) do
      def success?
        summary_errors.empty? && row_errors.empty?
      end

      def total_count
        created_count + updated_count + unchanged_count
      end
    end

    # Headers are matched on their start, ignoring case, because the sheet has long
    # headers with hints that change between versions, for example
    # "Times searched (May-Aug 2026)". Columns that are not listed here (Row,
    # Chapter title, Heading description) are ignored.
    COLUMN_PATTERNS = {
      chapter: /\Achapter\z/,
      real_user_search: /\Areal user search/,
      times_searched: /\Atimes searched/,
      likely_heading: /\Alikely heading/,
      description: /\Afull product description/,
      goods_nomenclature_item_id: /\Acommodity code/,
      status: /\Astatus\z/,
      completed_by: /\Acompleted by/,
      notes: /\Anotes\z/,
    }.freeze
    COLUMN_LABELS = {
      chapter: 'Chapter',
      real_user_search: 'Real user search',
      times_searched: 'Times searched',
      likely_heading: 'Likely heading',
      description: 'Full product description',
      goods_nomenclature_item_id: 'Commodity code',
      status: 'Status',
      completed_by: 'Completed by',
      notes: 'Notes',
    }.freeze
    REQUIRED_COLUMNS = %i[chapter real_user_search description goods_nomenclature_item_id status].freeze
    ATTRIBUTE_COLUMNS = (COLUMN_PATTERNS.keys - %i[status]).freeze
    DONE_STATUS = 'done'.freeze
    PLACEHOLDER_PREFIX = '(no real search'.freeze
    # Excel's "CSV UTF-8" export starts the file with this mark. Left in place it
    # would become part of the first header and stop that column being matched.
    BYTE_ORDER_MARK = "\uFEFF".freeze

    def initialize(csv_content:)
      @csv_content = csv_content.to_s.delete_prefix(BYTE_ORDER_MARK)
      @summary_errors = []
      @row_errors = []
      @skipped_count = 0
    end

    def call
      rows = parse_rows
      return failure_result if errors?

      records = build_records(rows)
      return failure_result if errors?

      persist(records)
    rescue CSV::MalformedCSVError => e
      @summary_errors << error(detail: "CSV could not be parsed: #{e.message}")
      failure_result
    end

  private

    def parse_rows
      csv = CSV.parse(@csv_content, headers: true)
      columns = match_columns(csv.headers)
      return [] if errors?

      csv.each_with_index.filter_map do |row, index|
        next if row.to_h.values.all?(&:blank?)

        columns.transform_values { |header| row[header].to_s.strip }.merge(line_number: index + 2)
      end
    end

    def match_columns(headers)
      normalised = headers.compact.map { |header| [header, header.to_s.squish.downcase] }

      columns = COLUMN_PATTERNS.each_with_object({}) do |(column, pattern), found|
        header, = normalised.find { |_header, downcased| pattern.match?(downcased) }
        found[column] = header if header
      end

      missing = REQUIRED_COLUMNS - columns.keys
      if missing.any?
        @summary_errors << error(detail: "The file is missing these columns: #{missing.map { |column| COLUMN_LABELS.fetch(column) }.to_sentence}")
      end

      columns
    end

    def build_records(rows)
      finished, unfinished = rows.partition { |row| finished?(row) }
      @skipped_count = unfinished.size

      validate_placeholders(finished)
      validate_repeated_searches(finished)

      finished.map { |row| record_for(row) }
    end

    def finished?(row)
      row[:status].casecmp?(DONE_STATUS) && row[:description].present? && row[:goods_nomenclature_item_id].present?
    end

    def validate_placeholders(rows)
      rows.each do |row|
        next unless row[:real_user_search].downcase.start_with?(PLACEHOLDER_PREFIX)

        add_row_error(row, :real_user_search, 'still shows the "(no real search available...)" placeholder. Replace it with the search term that was used')
      end
    end

    def validate_repeated_searches(rows)
      first_line = {}

      rows.each do |row|
        key = row[:real_user_search].squish.downcase
        next if key.blank?

        if first_line.key?(key)
          add_row_error(row, :real_user_search, "appears more than once in the file (first on line #{first_line[key]})")
        else
          first_line[key] = row[:line_number]
        end
      end
    end

    def record_for(row)
      existing = SyntheticAtar.by_real_user_search(row[:real_user_search]).first
      record = existing || SyntheticAtar.new
      # Only the columns that are in the file are set, so a file without a
      # "Completed by" column cannot blank the values already stored.
      record.set(row.slice(*ATTRIBUTE_COLUMNS))

      unless record.valid?
        record.errors.each do |attribute, messages|
          messages.each { |message| add_row_error(row, attribute, message) }
        end
      end

      record
    end

    def persist(records)
      created = updated = unchanged = 0

      SyntheticAtar.db.transaction do
        records.each do |record|
          if record.new?
            record.save
            created += 1
          elsif record.modified?
            record.save
            updated += 1
          else
            unchanged += 1
          end
        end
      end

      Result.new(
        created_count: created,
        updated_count: updated,
        unchanged_count: unchanged,
        skipped_count: @skipped_count,
        summary_errors: [],
        row_errors: [],
      )
    end

    def add_row_error(row, attribute, message)
      label = COLUMN_LABELS.fetch(attribute.to_sym, attribute.to_s.humanize)

      @row_errors << error(
        detail: "Line #{row[:line_number]}: #{label} #{message}",
        pointer: "/data/attributes/csv/#{row[:line_number]}/#{attribute}",
      )
    end

    def failure_result
      Result.new(
        created_count: 0,
        updated_count: 0,
        unchanged_count: 0,
        skipped_count: @skipped_count,
        summary_errors: @summary_errors,
        row_errors: @row_errors,
      )
    end

    def errors?
      @summary_errors.any? || @row_errors.any?
    end

    def error(detail:, pointer: nil)
      { detail: }.tap { |payload| payload[:source] = { pointer: } if pointer }
    end
  end
end
