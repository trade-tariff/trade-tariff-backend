# frozen_string_literal: true

require 'zip'

module SearchExport
  class Workbook
    Result = Data.define(:bytes, :omitted_count, :row_count)
    TooManyRows = Class.new(StandardError)
    MAX_ROWS = 200_000
    TEMPLATE = Rails.root.join('lib/search_export/AI-1253-search-export-template.xlsx').freeze
    SEARCHES_SHEET = 'xl/worksheets/sheet2.xml'
    INSTRUCTIONS_SHEET = 'xl/worksheets/sheet1.xml'
    WRAP_STYLE = '24'
    QUESTION_GROUPS = [%w[E F G], %w[H I J], %w[K L M], %w[N O P], %w[Q R S], %w[T U V], %w[W X Y]].freeze
    END_PAGE_TYPES = [TerminalPage::RESULT, TerminalPage::INTERCEPT, TerminalPage::NO_RESULT].freeze

    def self.call(from:, to:, generated_at: Time.current)
      new(from:, to:, generated_at:).call
    end

    def self.candidate_count(from:, to:)
      Journey.for_export(from:, to:).count
    end

    def initialize(from:, to:, generated_at:)
      @from = from
      @to = to
      @generated_at = generated_at
    end

    def call
      raise TooManyRows, 'Shorten the date range. This export is limited to 200,000 journeys.' if candidates.count > MAX_ROWS

      written, omitted = partition
      Result.new(bytes: fill(written, omitted), omitted_count: omitted, row_count: written.size)
    end

  private

    attr_reader :from, :to, :generated_at

    def candidates
      Journey.for_export(from:, to:)
    end

    def partition
      rows = candidates.all
      clicks = clicks_for(rows.map(&:request_id))
      written = []
      omitted = 0
      rows.each do |journey|
        if writable?(journey)
          written << [journey, clicks.fetch(journey.request_id, [])]
        else
          omitted += 1
        end
      end
      [written, omitted]
    end

    def clicks_for(request_ids)
      return {} if request_ids.empty?

      cutoff = generated_at
      ResultClick.where(request_id: request_ids)
                 .where { clicked_at <= cutoff }
                 .order(:clicked_at, :result_rank)
                 .all
                 .group_by(&:request_id)
    end

    def writable?(journey)
      return false if journey.omitted || journey.truncated
      return false if journey.request_id.blank? || journey.query.blank?
      return false unless END_PAGE_TYPES.include?(journey.end_page_type)

      answers = array_of(journey.answers)
      return false if answers.size > 7
      return false unless answers.all? { |answer| offered_answer?(answer) }

      results = array_of(journey.results)
      if journey.end_page_type == TerminalPage::RESULT
        results.any? && results.all? { |result| valid_result?(result) }
      else
        results.empty?
      end
    end

    def offered_answer?(answer)
      selected = field(answer, 'answer').to_s
      options = Array(field(answer, 'options')).map(&:to_s)
      field(answer, 'question').present? && selected.present? && options.include?(selected)
    end

    def valid_result?(result)
      field(result, 'commodity_code').to_s.match?(/\A\d{10}\z/) && field(result, 'description').present?
    end

    def fill(written, omitted)
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'classifier-workbook.xlsx')
        FileUtils.cp(TEMPLATE, path)
        Zip::File.open(path) do |zip|
          searches_xml = zip.read(SEARCHES_SHEET)
          instructions_xml = zip.read(INSTRUCTIONS_SHEET)
          zip.get_output_stream(SEARCHES_SHEET) { |out| out.write(write_searches(searches_xml, written)) }
          zip.get_output_stream(INSTRUCTIONS_SHEET) { |out| out.write(write_omitted(instructions_xml, omitted)) }
        end
        File.binread(path)
      end
    end

    def write_searches(xml, written)
      rows = written.each_with_index.map { |(journey, clicks), index| row_xml(index + 3, journey, clicks) }.join
      last_row = written.empty? ? 2 : written.size + 2
      xml.sub('ref="A1:AI2"', %(ref="A1:AI#{last_row}"))
         .sub('</sheetData>', "#{rows}</sheetData>")
    end

    def write_omitted(xml, omitted)
      cell = %(<row r="36"><c r="B36" t="inlineStr"><is><t>#{escape("Omitted journeys: #{omitted}")}</t></is></c></row>)
      xml.sub('</sheetData>', "#{cell}</sheetData>")
    end

    def row_xml(number, journey, clicks)
      values = row_values(journey, clicks)
      lines = values.values.map { |value| value.to_s.count("\n") + 1 }.max
      height = [15 * lines, 409].min
      cells = values.sort_by { |column, _value| [column.length, column] }
                    .filter_map { |column, value| cell_xml("#{column}#{number}", value) }.join
      %(<row r="#{number}" ht="#{height}" customHeight="1">#{cells}</row>)
    end

    def row_values(journey, clicks)
      results = array_of(journey.results)
      {
        'A' => journey.request_id,
        'B' => journey.query,
        'C' => array_of(journey.expansion_terms).any? ? 'Yes' : 'No',
        'D' => array_of(journey.expansion_terms).join("\n"),
        'Z' => journey.end_page_type,
        'AA' => results.map { |result| "#{field(result, 'commodity_code')} - #{field(result, 'description')}" }.join("\n"),
        'AB' => results.map { |result| field(result, 'confidence_label').to_s }.join("\n"),
        'AC' => click_lines(results, clicks),
      }.merge(question_cells(array_of(journey.answers))).reject { |_column, value| value.nil? || value == '' }
    end

    def question_cells(answers)
      QUESTION_GROUPS.each_with_index.with_object({}) do |(columns, index), cells|
        answer = answers[index]
        next unless answer

        cells[columns[0]] = field(answer, 'question').to_s
        cells[columns[1]] = Array(field(answer, 'options')).join("\n")
        cells[columns[2]] = field(answer, 'answer').to_s
      end
    end

    def click_lines(results, clicks)
      offered = results.to_h { |result| [field(result, 'commodity_code').to_s, "#{field(result, 'commodity_code')} - #{field(result, 'description')}"] }
      clicks.sort_by { |click| [click.clicked_at, click.result_rank.to_i] }
            .uniq(&:commodity_code)
            .filter_map { |click| offered[click.commodity_code] }
            .join("\n")
    end

    def cell_xml(reference, value)
      return if value.blank?

      text = value.to_s
      space = text.match?(/\A\s|\s\z|\n/) ? ' xml:space="preserve"' : ''
      %(<c r="#{reference}" s="#{WRAP_STYLE}" t="inlineStr"><is><t#{space}>#{escape(text)}</t></is></c>)
    end

    def escape(text)
      text.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;').gsub("\n", '&#10;')
    end

    def array_of(value)
      value.is_a?(Array) ? value : Array(value)
    end

    def field(record, key)
      record[key] || record[key.to_sym]
    end
  end
end
