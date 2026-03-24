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

      def self.call(workbook:, report_rows:)
        new(workbook:, report_rows:).call
      end

      def initialize(workbook:, report_rows:)
        @workbook = workbook
        @report_rows = report_rows
      end

      def call
        workbook.add_worksheet(name: SHEET_NAME) do |sheet|
          add_intro_rows(sheet)
          add_headers(sheet)
          add_rows(sheet)
          add_table_styling(sheet)
          set_column_widths(sheet)
        end
      end

      private

      attr_reader :report_rows, :workbook

      def report_service_class
        ActiveCommoditiesReportService
      end

      def add_intro_rows(sheet)
        downloaded_on = TimeMachine.now { Time.zone.today.strftime('%d/%m/%Y') }
        add_title_row(sheet, downloaded_on)
        add_blank_intro_row(sheet, 2)
        add_instruction_row(sheet)
        add_upload_row(sheet)
        add_blank_intro_row(sheet, 5)
      end

      def add_headers(sheet)
        header_row = sheet.add_row(HEADERS, style: full_width_styles(styles[:header]))
        header_row.height = TABLE_HEADER_ROW_HEIGHT
      end

      def add_rows(sheet)
        report_rows.each do |row|
          sheet.add_row(
            ["#{row[:code]}\n ", row[:chapter], description_cell_value(row[:description], row[:status]), row[:status]],
            types: [:string, :string, nil, :string],
            style: row_styles(row[:status]),
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

      def add_title_row(sheet, downloaded_on)
        title_row = sheet.add_row(
          intro_row_values("Your commodities (#{downloaded_on})"),
          style: full_width_styles(styles[:title]),
        )
        title_row.height = TITLE_ROW_HEIGHT
        sheet.merge_cells('A1:D1')
      end

      def add_blank_intro_row(sheet, row_number)
        blank_row = sheet.add_row(blank_intro_row_values, style: full_width_styles(styles[:intro_blank]))
        blank_row.height = BLANK_ROW_HEIGHT
        sheet.merge_cells("A#{row_number}:D#{row_number}")
      end

      def add_instruction_row(sheet)
        instruction_row = sheet.add_row(
          intro_row_values(build_instructions_rich_text),
          style: [styles[:intro_text], styles[:intro_blank], styles[:intro_blank], styles[:intro_blank]],
        )
        instruction_row.height = INSTRUCTIONS_ROW_HEIGHT
        sheet.merge_cells(INSTRUCTIONS_MERGE_RANGE)
      end

      def add_upload_row(sheet)
        upload_row = sheet.add_row(
          intro_row_values('Replace all commodities (upload)'),
          style: [styles[:upload_link], styles[:intro_blank], styles[:intro_blank], styles[:intro_blank]],
        )
        upload_row.height = REPLACE_LINK_ROW_HEIGHT
        sheet.add_hyperlink(location: REPLACE_ALL_COMMODITIES_UPLOAD_URL, ref: upload_row.cells[0])
      end

      def row_styles(status)
        [
          styles[:commodity_code],
          styles[:chapter],
          styles[:description],
          styles[:statuses].fetch(status),
        ]
      end

      def styles
        @styles ||= build_styles
      end

      def build_styles
        {
          header: workbook.styles.add_style(
            b: true,
            sz: HEADER_FONT_SIZE,
            fg_color: WHITE_COLOR,
            bg_color: HEADER_BACKGROUND_COLOR,
            alignment: { horizontal: :left, vertical: :center, indent: CELL_INDENT },
          ),
          title: workbook.styles.add_style(
            b: true,
            sz: 24,
            fg_color: DEFAULT_DARK_COLOR,
            bg_color: WHITE_COLOR,
            border: { style: :medium, color: DEFAULT_DARK_COLOR, edges: [:bottom] },
            alignment: { vertical: :top },
          ),
          intro_text: workbook.styles.add_style(
            base_intro_row_style_options.merge(
              alignment: { wrap_text: true, vertical: :top },
            ),
          ),
          intro_blank: workbook.styles.add_style(bg_color: WHITE_COLOR),
          upload_link: workbook.styles.add_style(
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
          ),
          commodity_code: workbook.styles.add_style(base_text_style_options(bold: true)),
          description: workbook.styles.add_style(base_text_style_options),
          chapter: workbook.styles.add_style(base_text_style_options),
          statuses: {
            report_service_class::ACTIVE => workbook.styles.add_style(
              status_style_options(ACTIVE_BACKGROUND_COLOR, ACTIVE_FONT_COLOR),
            ),
            report_service_class::EXPIRED => workbook.styles.add_style(
              status_style_options(EXPIRED_BACKGROUND_COLOR, EXPIRED_FONT_COLOR),
            ),
            report_service_class::ERROR_FROM_UPLOAD => workbook.styles.add_style(
              status_style_options(
                ERROR_FROM_UPLOAD_BACKGROUND_COLOR,
                ERROR_FROM_UPLOAD_FONT_COLOR,
              ),
            ),
          },
        }
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

      def base_intro_row_style_options
        {
          sz: ROW_FONT_SIZE,
          fg_color: DEFAULT_DARK_COLOR,
          bg_color: WHITE_COLOR,
        }
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

      def description_cell_value(description_payload, status)
        return report_service_class::NOT_APPLICABLE if status == report_service_class::ERROR_FROM_UPLOAD
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
    end
  end
end
