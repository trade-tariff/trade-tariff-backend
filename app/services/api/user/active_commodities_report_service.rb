module Api
  module User
    class ActiveCommoditiesReportService
      HEADERS = %w[Commodity Chapter Description Status].freeze
      SHEET_NAME = 'Your commodities'.freeze
      TABLE_NAME = 'Your_commodities_from_your_commodity_watch_list'.freeze
      ACTIVE = 'Active'.freeze
      EXPIRED = 'Expired'.freeze
      ERROR_FROM_UPLOAD = 'Error from upload'.freeze
      NOT_APPLICABLE = 'Not applicable'.freeze
      BULLET_PREFIX = '• '.freeze
      ACTIVE_BACKGROUND_COLOR = 'FFCFE4DC'.freeze
      ACTIVE_FONT_COLOR = 'FF083D29'.freeze
      EXPIRED_BACKGROUND_COLOR = 'FFFFEE80'.freeze
      EXPIRED_FONT_COLOR = 'FF7A3C1C'.freeze
      ERROR_FROM_UPLOAD_BACKGROUND_COLOR = 'FFF4D7D7'.freeze
      ERROR_FROM_UPLOAD_FONT_COLOR = 'FF651B1B'.freeze
      HEADER_BACKGROUND_COLOR = 'FF1A65A6'.freeze
      UPLOAD_LINK_BACKGROUND_COLOR = 'FF0F7A52'.freeze
      WHITE_COLOR = 'FFFFFFFF'.freeze
      DEFAULT_DARK_COLOR = 'FF0B0C0C'.freeze
      HEADER_FONT_SIZE = 14
      ROW_FONT_SIZE = 12
      TITLE_ROW_HEIGHT = 35
      INSTRUCTIONS_ROW_HEIGHT = 110
      BLANK_ROW_HEIGHT = 25
      TABLE_HEADER_ROW_HEIGHT = 34
      REPLACE_LINK_ROW_HEIGHT = 54
      CELL_INDENT = 1
      TABLE_START_ROW = 6
      INSTRUCTIONS_MERGE_RANGE = 'A3:D3'.freeze
      COLUMN_WIDTHS = [36, 28, 90, 24].freeze
      REPLACE_ALL_COMMODITIES_UPLOAD_URL = 'https://www.trade-tariff.service.gov.uk/subscriptions/mycommodities/new?utm_source=watch%2Blists&utm_medium=excel&utm_campaign=ccwl%2Bdata'.freeze

      def self.call(active_codes, expired_codes, invalid_codes)
        new(active_codes, expired_codes, invalid_codes).call
      end

      def initialize(active_codes, expired_codes, invalid_codes)
        @active_codes = normalize_codes(active_codes)
        @expired_codes = normalize_codes(expired_codes)
        @invalid_codes = normalize_codes(invalid_codes)
      end

      def call
        package = Axlsx::Package.new
        package.use_shared_strings = true

        workbook = package.workbook
        workbook.add_worksheet(name: SHEET_NAME) do |sheet|
          add_intro_rows(sheet, workbook)
          add_headers(sheet, workbook)
          add_rows(sheet, workbook)
          add_table_styling(sheet)
          set_column_widths(sheet)
        end

        package
      end

      private

      attr_reader :active_codes, :expired_codes, :invalid_codes

      def normalize_codes(codes)
        codes.to_a.map(&:to_s).uniq
      end

      def add_headers(sheet, workbook)
        header_style = workbook.styles.add_style(
          b: true,
          sz: HEADER_FONT_SIZE,
          fg_color: WHITE_COLOR,
          bg_color: HEADER_BACKGROUND_COLOR,
          alignment: { horizontal: :left, vertical: :center, indent: CELL_INDENT },
        )
        header_row = sheet.add_row(HEADERS, style: [header_style] * HEADERS.length)
        header_row.height = TABLE_HEADER_ROW_HEIGHT
      end

      def add_intro_rows(sheet, workbook)
        title_style = workbook.styles.add_style(
          b: true,
          sz: 24,
          fg_color: DEFAULT_DARK_COLOR,
          bg_color: WHITE_COLOR,
          border: { style: :medium, color: DEFAULT_DARK_COLOR, edges: [:bottom] },
          alignment: { vertical: :top },
        )
        base_intro_row_style_options = {
          sz: ROW_FONT_SIZE,
          fg_color: DEFAULT_DARK_COLOR,
          bg_color: WHITE_COLOR,
        }

        intro_text_style_options = base_intro_row_style_options.merge(
          alignment: { wrap_text: true, vertical: :top },
        )
        intro_text_style = workbook.styles.add_style(intro_text_style_options)
        intro_blank_style = workbook.styles.add_style(bg_color: WHITE_COLOR)
        upload_link_style = workbook.styles.add_style(
          b: true,
          sz: ROW_FONT_SIZE,
          u: true,
          fg_color: WHITE_COLOR,
          bg_color: UPLOAD_LINK_BACKGROUND_COLOR,
          alignment: {
            horizontal: :center,
            vertical: :center,
            indent: 1,
          },
        )

        downloaded_on = TimeMachine.now { Time.zone.today.strftime('%d/%m/%Y') }

        title_row = sheet.add_row(
          intro_row_values("Your commodities (#{downloaded_on})"),
          style: [title_style, title_style, title_style, title_style],
        )
        title_row.height = TITLE_ROW_HEIGHT
        sheet.merge_cells('A1:D1')

        blank_top_row = sheet.add_row(blank_intro_row_values, style: [intro_blank_style] * 4)
        blank_top_row.height = BLANK_ROW_HEIGHT
        sheet.merge_cells('A2:D2')

        instruction_row = sheet.add_row(
          intro_row_values(build_instructions_rich_text),
          style: [intro_text_style, intro_blank_style, intro_blank_style, intro_blank_style],
        )
        sheet.merge_cells(INSTRUCTIONS_MERGE_RANGE)
        instruction_row.height = INSTRUCTIONS_ROW_HEIGHT

        upload_row = sheet.add_row(
          intro_row_values('Replace all commodities (upload)'),
          style: [upload_link_style, intro_blank_style, intro_blank_style, intro_blank_style],
        )
        upload_row.height = REPLACE_LINK_ROW_HEIGHT
        sheet.add_hyperlink(location: REPLACE_ALL_COMMODITIES_UPLOAD_URL, ref: upload_row.cells[0])

        blank_bottom_row = sheet.add_row(blank_intro_row_values, style: [intro_blank_style] * 4)
        blank_bottom_row.height = BLANK_ROW_HEIGHT
        sheet.merge_cells('A5:D5')
      end

      def add_rows(sheet, workbook)
        report_rows.each do |row|
          sheet.add_row(
            ["#{row[:code]}\n ", row[:chapter], description_cell_value(row[:description], row[:status]), row[:status]],
            types: [:string, :string, nil, :string],
            style: row_styles(workbook, row[:status]),
          )
        end
      end

      def add_table_styling(sheet)
        return if report_rows.empty?

        last_row = TABLE_START_ROW + report_rows.length
        sheet.add_table(
          "A#{TABLE_START_ROW}:D#{last_row}",
          name: TABLE_NAME,
          style_info: {
            name: 'TableStyleLight15',
            show_first_column: false,
            show_last_column: false,
            show_row_stripes: true,
            show_column_stripes: false,
          },
        )
      end

      def set_column_widths(sheet)
        sheet.column_widths(*COLUMN_WIDTHS)
      end

      def report_rows
        @report_rows ||= begin
          all_codes = (active_codes + expired_codes + invalid_codes).uniq.sort
          valid_codes = all_codes - invalid_codes
          descriptions = load_classification_descriptions(valid_codes)
          load_chapter_names(valid_codes)
          statuses = status_by_code

          all_codes.map do |code|
            status = statuses[code]

            {
              code: code,
              chapter: chapter_display_value(code, status),
              description: description_display_value(code, descriptions, status),
              status: status,
            }
          end
        end
      end

      def intro_row_values(*values)
        values.fill('', values.length...HEADERS.length)
      end

      def blank_intro_row_values
        Array.new(HEADERS.length, '')
      end

      def status_by_code
        @status_by_code ||= {}.tap do |statuses|
          active_codes.each { |code| statuses[code] = ACTIVE }
          expired_codes.each { |code| statuses[code] ||= EXPIRED }
          invalid_codes.each { |code| statuses[code] ||= ERROR_FROM_UPLOAD }
        end
      end

      def row_styles(workbook, status)
        styles = table_styles(workbook)

        [
          styles[:commodity_code],
          styles[:chapter],
          styles[:description],
          styles.fetch(status),
        ]
      end

      def table_styles(workbook)
        @table_styles ||=
          {
            commodity_code: workbook.styles.add_style(base_text_style_options(bold: true)),
            description: workbook.styles.add_style(base_text_style_options),
            chapter: workbook.styles.add_style(base_text_style_options),
            ACTIVE => workbook.styles.add_style(status_style_options(ACTIVE_BACKGROUND_COLOR, ACTIVE_FONT_COLOR)),
            EXPIRED => workbook.styles.add_style(status_style_options(EXPIRED_BACKGROUND_COLOR, EXPIRED_FONT_COLOR)),
            ERROR_FROM_UPLOAD => workbook.styles.add_style(status_style_options(ERROR_FROM_UPLOAD_BACKGROUND_COLOR, ERROR_FROM_UPLOAD_FONT_COLOR)),
          }
      end

      def base_row_style_options
        {
          sz: ROW_FONT_SIZE,
          alignment: { horizontal: :left, vertical: :top, indent: CELL_INDENT, wrap_text: true },
        }
      end

      def base_text_style_options(bold: false)
        base_row_style_options.merge(fg_color: DEFAULT_DARK_COLOR, b: bold)
      end

      def status_style_options(background_color, font_color)
        base_text_style_options(bold: true).merge(
          bg_color: background_color,
          fg_color: font_color,
        )
      end

      def description_display_value(code, descriptions, status)
        return NOT_APPLICABLE if status == ERROR_FROM_UPLOAD

        descriptions.fetch(code, {})
      end

      def description_cell_value(description_payload, status)
        return NOT_APPLICABLE if status == ERROR_FROM_UPLOAD
        return description_payload.to_s unless description_payload.is_a?(Hash)

        hierarchy_levels = Array(description_payload[:hierarchy_levels] || description_payload['hierarchy_levels'])
        has_heading = description_payload[:has_heading] || description_payload['has_heading']
        plain_description = description_payload[:plain_description] || description_payload['plain_description']
        return plain_description.to_s if hierarchy_levels.empty?

        build_hierarchy_rich_text(hierarchy_levels, has_heading: has_heading)
      end

      def build_instructions_rich_text
        rich_text = Axlsx::RichText.new
        rich_text.add_run("Updating your commodity watch list:\n", b: true)
        rich_text.add_run("All your active and expired codes, as well as errors, are listed on this spreadsheet.\n\n")
        rich_text.add_run("You can edit, add and remove codes from this spreadsheet or your own.\n\n")
        rich_text.add_run('You can then upload it to update your commodity watchlist. ')
        rich_text.add_run('Ensure all codes are listed in column A.', b: true)
        rich_text
      end

      def build_hierarchy_rich_text(hierarchy_levels, has_heading:)
        last_level = hierarchy_levels.last.to_s
        rich_text = Axlsx::RichText.new

        if has_heading
          hierarchy_levels[0...-1].each do |level|
            rich_text.add_run("#{BULLET_PREFIX}#{level}\n")
          end
          rich_text.add_run("\n")
        end

        rich_text.add_run(last_level, b: true)
        rich_text.add_run("\n")
        rich_text
      end

      def chapter_number_for(code)
        normalized_code = code.to_s
        return unless normalized_code.match?(/\A\d{10}\z/)

        normalized_code[0, 2]
      end

      def chapter_display_value(code, status)
        return NOT_APPLICABLE if status == ERROR_FROM_UPLOAD

        chapter_number = chapter_number_for(code)
        return '' if chapter_number.blank?

        formatted_chapter_number = chapter_number.to_s.rjust(2, '0')
        chapter_name = chapter_names[chapter_number].to_s
        "#{formatted_chapter_number}: #{chapter_name}".strip
      end

      def chapter_names
        @chapter_names ||= {}
      end

      def load_chapter_names(codes)
        chapter_codes_by_number = codes.each_with_object({}) do |code, result|
          chapter_number = chapter_number_for(code)
          next if chapter_number.blank?

          result[chapter_number] = "#{chapter_number}00000000"
        end

        return chapter_names if chapter_codes_by_number.empty?

        chapter_descriptions = Chapter.actual
          .where(goods_nomenclature_item_id: chapter_codes_by_number.values)
          .eager(:goods_nomenclature_descriptions)
          .all
          .each_with_object({}) do |chapter, descriptions|
            descriptions[chapter.goods_nomenclature_item_id] = chapter.formatted_description.to_s
          end

        @chapter_names = chapter_codes_by_number.transform_values do |chapter_code|
          chapter_descriptions[chapter_code].to_s
        end
      end

      def load_classification_descriptions(codes)
        CachedCommodityDescriptionService.fetch_for_codes(codes, include_hierarchy: true)
      end
    end
  end
end
