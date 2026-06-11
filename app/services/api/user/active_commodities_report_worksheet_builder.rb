module Api
  module User
    class ActiveCommoditiesReportWorksheetBuilder
      HEADERS = %w[Commodity Chapter Description Status].freeze
      SHEET_NAME = 'Your commodities'.freeze
      TABLE_NAME = 'Your_commodities_from_your_commodity_watch_list'.freeze
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
      TITLE_ROW_HEIGHT = 40
      FIRST_INSTRUCTION_ROW_HEIGHT = 40
      INSTRUCTION_LINE_HEIGHT = 30
      BLANK_ROW_HEIGHT = 40
      TABLE_HEADER_ROW_HEIGHT = 34
      REPLACE_LINK_ROW_HEIGHT = 60
      CELL_INDENT = 1
      TABLE_START_ROW = 8
      COLUMN_WIDTHS = [36, 28, 90, 24].freeze
      REPLACE_ALL_COMMODITIES_UPLOAD_URL = 'https://www.trade-tariff.service.gov.uk/subscriptions/mycommodities/new?utm_source=watch%2Blists&utm_medium=excel&utm_campaign=ccwl%2Bdata'.freeze

      def self.call(workbook:, report_rows:)
        new(workbook:, report_rows:).call
      end

      def initialize(workbook:, report_rows:)
        @workbook = workbook
        @report_rows = report_rows
      end

      def call
        sheet = workbook.add_worksheet(SHEET_NAME)
        add_intro_rows(sheet)
        add_headers(sheet)
        add_rows(sheet)
        add_table_styling(sheet)
        set_column_widths(sheet)
      end

      private

      attr_reader :report_rows, :workbook

      def add_intro_rows(sheet)
        styles = intro_styles

        add_title_row(sheet, styles.fetch(:title))
        add_instruction_rows(sheet, styles)
        add_upload_row(sheet, styles)
        add_blank_bottom_row(sheet, styles.fetch(:blank))
      end

      def add_headers(sheet)
        sheet.append_row(HEADERS, full_width_styles(table_styles.fetch(:header)))
        sheet.set_row(TABLE_START_ROW - 1, TABLE_HEADER_ROW_HEIGHT, table_styles.fetch(:header))
      end

      def add_rows(sheet)
        report_rows.each do |row|
          sheet.append_row(
            ["#{row[:code]}\n ", row[:chapter], description_cell_value(row[:description]), row[:status]],
            row_styles(row[:status]),
          )
        end
      end

      def add_table_styling(sheet)
        return if report_rows.empty?

        header_row_index = TABLE_START_ROW - 1
        last_row_index = header_row_index + report_rows.length - 1
        sheet.add_table(header_row_index, 0, last_row_index, HEADERS.length - 1, name: TABLE_NAME, style: 'TableStyleLight15', columns: HEADERS)
      end

      def set_column_widths(sheet)
        COLUMN_WIDTHS.each_with_index do |width, index|
          sheet.set_column_width(index, width)
        end
      end

      def add_title_row(sheet, title_style)
        downloaded_on = TimeMachine.now { Time.zone.today.strftime('%d/%m/%Y') }
        sheet.append_row(
          intro_row_values('Your commodities', "(#{downloaded_on})"),
          full_width_styles(title_style),
        )
        sheet.set_row(0, TITLE_ROW_HEIGHT, title_style)
      end

      def add_instruction_rows(sheet, styles)
        instruction_rows_data.each_with_index do |row_data, index|
          style = index.zero? ? styles.fetch(:instruction_first) : styles.fetch(:instruction)
          sheet.append_row(
            [row_data[:text], nil, nil, nil],
            [style, styles.fetch(:blank), styles.fetch(:blank), styles.fetch(:blank)],
          )
          sheet.set_row(index + 1, index.zero? ? FIRST_INSTRUCTION_ROW_HEIGHT : INSTRUCTION_LINE_HEIGHT, style)
        end
      end

      def add_upload_row(sheet, styles)
        row_index = sheet.last_row_number + 1
        sheet.append_row(
          ['', '', '', ''],
          [styles.fetch(:upload_link), styles.fetch(:blank), styles.fetch(:blank), styles.fetch(:blank)],
        )
        sheet.set_row(row_index, REPLACE_LINK_ROW_HEIGHT, styles.fetch(:upload_link))
        sheet.write_url_opt(row_index, 0, REPLACE_ALL_COMMODITIES_UPLOAD_URL, styles.fetch(:upload_link), 'Replace all commodities (upload)', nil)
      end

      def add_blank_bottom_row(sheet, blank_style)
        sheet.append_row(blank_intro_row_values, full_width_styles(blank_style))
        sheet.set_row(sheet.last_row_number, BLANK_ROW_HEIGHT, blank_style)
      end

      def intro_styles
        base_intro_row_style_options = {
          sz: ROW_FONT_SIZE,
          fg_color: DEFAULT_DARK_COLOR,
          bg_color: WHITE_COLOR,
        }

        intro_text_style_options = base_intro_row_style_options.merge(
          alignment: { vertical: :top },
        )

        {
          title: workbook.add_format(
            bold: true,
            font_size: 24,
            font_color: color(DEFAULT_DARK_COLOR),
            bg_color: color(WHITE_COLOR),
            align: { v: :top },
          ),
          instruction: workbook.add_format(
            fast_excel_style_options(intro_text_style_options.merge(sz: 14)),
          ),
          instruction_first: workbook.add_format(
            fast_excel_style_options(intro_text_style_options.merge(sz: 16, b: true, alignment: { vertical: :bottom })),
          ),
          blank: workbook.add_format(bg_color: color(WHITE_COLOR)),
          upload_link: workbook.add_format(
            bold: true,
            font_size: ROW_FONT_SIZE,
            underline: :underline_single,
            font_color: color(WHITE_COLOR),
            bg_color: color(UPLOAD_LINK_BACKGROUND_COLOR),
            align: {
              h: :center,
              v: :center,
            },
            indent: 1,
          ),
        }
      end

      def table_styles
        @table_styles ||= build_table_styles
      end

      def build_table_styles
        {
          header: workbook.add_format(
            bold: true,
            font_size: HEADER_FONT_SIZE,
            font_color: color(WHITE_COLOR),
            bg_color: color(HEADER_BACKGROUND_COLOR),
            align: { h: :left, v: :center },
            indent: CELL_INDENT,
          ),
          commodity_code: workbook.add_format(fast_excel_style_options(base_text_style_options(bold: true))),
          description: workbook.add_format(fast_excel_style_options(base_text_style_options)),
          chapter: workbook.add_format(fast_excel_style_options(base_text_style_options)),
          statuses: {
            ActiveCommoditiesReportService::ACTIVE => workbook.add_format(
              fast_excel_style_options(status_style_options(ACTIVE_BACKGROUND_COLOR, ACTIVE_FONT_COLOR)),
            ),
            ActiveCommoditiesReportService::EXPIRED => workbook.add_format(
              fast_excel_style_options(status_style_options(EXPIRED_BACKGROUND_COLOR, EXPIRED_FONT_COLOR)),
            ),
            ActiveCommoditiesReportService::ERROR_FROM_UPLOAD => workbook.add_format(
              fast_excel_style_options(
                status_style_options(
                  ERROR_FROM_UPLOAD_BACKGROUND_COLOR,
                  ERROR_FROM_UPLOAD_FONT_COLOR,
                ),
              ),
            ),
          },
        }
      end

      def row_styles(status)
        [
          table_styles.fetch(:commodity_code),
          table_styles.fetch(:chapter),
          table_styles.fetch(:description),
          table_styles.fetch(:statuses).fetch(status),
        ]
      end

      def intro_row_values(*values)
        values.fill('', values.length...HEADERS.length)
      end

      def blank_intro_row_values
        Array.new(HEADERS.length, '')
      end

      def full_width_styles(style)
        [style] * HEADERS.length
      end

      def base_row_style_options
        {
          sz: ROW_FONT_SIZE,
          alignment: {
            horizontal: :left,
            vertical: :top,
            indent: CELL_INDENT,
            wrap_text: true,
          },
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

      def description_cell_value(description_payload)
        return description_payload.to_s unless description_payload.is_a?(Hash)

        hierarchy_levels = Array(description_payload[:hierarchy_levels])
        has_heading = description_payload[:has_heading]
        plain_description = description_payload[:plain_description]
        return plain_description.to_s if hierarchy_levels.empty?

        build_hierarchy_rich_text(hierarchy_levels, has_heading: has_heading)
      end

      def instruction_rows_data
        [
          { text: 'Updating your commodity watch list:' },
          { text: 'All your active and expired codes, as well as errors, are listed on this spreadsheet.' },
          { text: 'You can edit, add and remove codes from this spreadsheet or your own.' },
          { text: build_upload_instructions_rich_text },
        ]
      end

      def build_upload_instructions_rich_text
        FastExcel::RichString.new([
          { text: 'You can then upload it to update your commodity watchlist. ' },
          { text: 'Ensure all codes are listed in column A.', format: workbook.add_format(bold: true, font_size: 14) },
        ])
      end

      def build_hierarchy_rich_text(hierarchy_levels, has_heading:)
        last_level = hierarchy_levels.last.to_s
        fragments = []

        if has_heading
          hierarchy_levels[0...-1].each do |level|
            fragments << { text: "#{BULLET_PREFIX}#{level}\n" }
          end
          fragments << { text: "\n" }
        end

        fragments << { text: last_level, format: hierarchy_level_format }
        fragments << { text: "\n" }
        FastExcel::RichString.new(fragments)
      end

      def hierarchy_level_format
        @hierarchy_level_format ||= workbook.add_format(bold: true)
      end

      def fast_excel_style_options(options)
        style_options = {
          font_size: options[:sz],
          font_color: color(options[:fg_color]),
          bg_color: color(options[:bg_color]),
          align: fast_excel_alignment(options.dig(:alignment, :horizontal), options.dig(:alignment, :vertical)),
          indent: options.dig(:alignment, :indent),
        }.compact
        style_options[:bold] = true if options[:b]
        style_options[:text_wrap] = true if options.dig(:alignment, :wrap_text)
        style_options
      end

      def fast_excel_alignment(horizontal, vertical)
        {}.tap do |alignment|
          alignment[:h] = horizontal if horizontal
          alignment[:v] = vertical if vertical
        end
      end

      def color(argb)
        return unless argb

        argb.to_s.delete_prefix('FF').to_i(16)
      end
    end
  end
end
