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

    def initialize(from:, to:, generated_at:)
      @from = from
      @to = to
      @generated_at = generated_at
    end

    def call
      @source = CloudwatchReader.call(from:, to:, generated_at:)
      raise TooManyRows, 'Shorten the date range. This export is limited to 200,000 journeys.' if @source.journeys.size > MAX_ROWS

      Tempfile.create(['classifier-rows', '.xml']) do |rows|
        written, omitted = write_rows(rows)
        rows.rewind
        Result.new(bytes: fill(rows, written, omitted), omitted_count: omitted, row_count: written)
      end
    end

  private

    attr_reader :from, :to, :generated_at

    def write_rows(output)
      written = 0
      omitted = 0
      @source.journeys.each do |journey|
        if writable?(journey)
          output.write(row_xml(written + 3, journey, @source.clicks.fetch(journey.request_id, [])))
          written += 1
        else
          omitted += 1
        end
      end
      [written, omitted]
    end

    def writable?(journey)
      return false if journey.omitted
      return false if journey.request_id.blank? || journey.query.blank?
      return false unless END_PAGE_TYPES.include?(journey.end_page_type)

      answers = journey.answers
      return false if answers.size > 7
      return false unless answers.all? { |answer| offered_answer?(answer) }

      results = journey.results
      if journey.end_page_type == TerminalPage::RESULT
        results.any? && results.all? { |result| valid_result?(result) }
      else
        results.empty?
      end
    end

    def offered_answer?(answer)
      answer['question'].present? && answer['answer'].present? && answer['options'].include?(answer['answer'])
    end

    def valid_result?(result)
      result['commodity_code'].to_s.match?(/\A\d{10}\z/) && result['description'].present?
    end

    def fill(rows, row_count, omitted)
      Dir.mktmpdir do |dir|
        path = File.join(dir, 'classifier-workbook.xlsx')
        FileUtils.cp(TEMPLATE, path)
        Zip::File.open(path) do |zip|
          searches_xml = zip.read(SEARCHES_SHEET)
          instructions_xml = zip.read(INSTRUCTIONS_SHEET)
          zip.get_output_stream(SEARCHES_SHEET) { |out| write_searches(out, searches_xml, rows, row_count) }
          zip.get_output_stream(INSTRUCTIONS_SHEET) { |out| out.write(write_omitted(instructions_xml, omitted)) }
        end
        File.binread(path)
      end
    end

    def write_searches(output, xml, rows, row_count)
      raise 'Unexpected classifier template dimensions' unless xml.include?('ref="A1:AI2"')

      header, tail = xml.sub('ref="A1:AI2"', %(ref="A1:AI#{row_count + 2}")).split('</sheetData>', 2)
      raise 'Missing classifier template sheet data' unless tail

      output.write(header)
      while (chunk = rows.read(64 * 1024))
        output.write(chunk)
      end
      output.write("</sheetData>#{tail}")
    end

    def write_omitted(xml, omitted)
      cell = %(<row r="36"><c r="B36" t="inlineStr"><is><t>#{escape("Omitted journeys: #{omitted}")}</t></is></c></row>)
      xml.sub('</sheetData>', "#{cell}</sheetData>")
    end

    def row_xml(number, journey, clicks)
      values = row_values(journey, clicks)
      lines = values.map { |column, value| wrapped_lines(column, value) }.max
      height = [15 * lines, 409].min
      cells = values.sort_by { |column, _value| [column.length, column] }
                    .filter_map { |column, value| cell_xml("#{column}#{number}", value) }.join
      %(<row r="#{number}" ht="#{height}" customHeight="1">#{cells}</row>)
    end

    def wrapped_lines(column, value)
      width = column_widths.fetch(column)
      # Excel column widths are approximate character counts. Reserve room for
      # padding and wide glyphs; include wrapping at word boundaries.
      capacity = [(width * 0.75).floor, 1].max
      value.to_s.split("\n", -1).sum do |line|
        used = 0
        lines = 1
        line.scan(/\S+\s*/).each do |word|
          if used.positive? && used + word.length > capacity
            lines += 1
            used = 0
          end
          total = used + word.length
          lines += [(total - 1) / capacity, 0].max
          used = total.zero? ? 0 : (total - 1) % capacity + 1
        end
        lines
      end
    end

    def column_widths
      @column_widths ||= Zip::File.open(TEMPLATE) do |zip|
        sheet = Nokogiri::XML(zip.read(SEARCHES_SHEET))
        sheet.remove_namespaces!
        styles = Nokogiri::XML(zip.read('xl/styles.xml'))
        styles.remove_namespaces!
        raise 'Classifier template style must wrap text' unless styles.at_xpath("//cellXfs/xf[#{WRAP_STYLE.to_i + 1}]/alignment")&.[]('wrapText') == '1'

        columns = ('A'..'AC').to_a
        sheet.xpath('//cols/col').each_with_object({}) do |node, widths|
          (node['min'].to_i..node['max'].to_i).each do |index|
            widths[columns[index - 1]] = node['width'].to_f if index <= columns.size
          end
        end
      end
    end

    def row_values(journey, clicks)
      results = journey.results
      {
        'A' => journey.request_id,
        'B' => journey.query,
        'C' => journey.expansion_terms.any? ? 'Yes' : 'No',
        'D' => journey.expansion_terms.join("\n"),
        'Z' => journey.end_page_type,
        'AA' => results.map { |result| result_line(result) }.join("\n"),
        'AB' => results.map { |result| result['confidence_label'] }.join("\n"),
        'AC' => click_lines(results, clicks),
      }.merge(question_cells(journey.answers)).reject { |_column, value| value.nil? || value == '' }
    end

    def question_cells(answers)
      QUESTION_GROUPS.each_with_index.with_object({}) do |(columns, index), cells|
        answer = answers[index]
        next unless answer

        cells[columns[0]] = answer['question']
        cells[columns[1]] = answer['options'].join("\n")
        cells[columns[2]] = answer['answer']
      end
    end

    def click_lines(results, clicks)
      offered = results.to_h { |result| [result['commodity_code'], result_line(result)] }
      clicks.sort_by(&:clicked_at)
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
      text.to_s.gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F\uFFFE\uFFFF]/, '').gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;').gsub("\n", '&#10;')
    end

    def result_line(result)
      "#{result['commodity_code']} - #{result['description']}"
    end
  end
end
