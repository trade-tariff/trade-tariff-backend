module Api
  module User
    class ActiveCommoditiesReportService
      HEADERS = %w[Commodity Description Status].freeze
      SHEET_NAME = 'Your commodities'.freeze
      ACTIVE = 'Active'.freeze
      EXPIRED = 'Expired'.freeze
      ERROR_FROM_UPLOAD = 'Error from upload'.freeze
      ACTIVE_BACKGROUND_COLOR = 'FFCFE4DC'.freeze
      ACTIVE_FONT_COLOR = 'FF083D29'.freeze
      EXPIRED_BACKGROUND_COLOR = 'FFFFEE80'.freeze
      EXPIRED_FONT_COLOR = 'FF7A3C1C'.freeze
      ERROR_FROM_UPLOAD_BACKGROUND_COLOR = 'FFF4D7D7'.freeze
      ERROR_FROM_UPLOAD_FONT_COLOR = 'FF651B1B'.freeze
      HEADER_BACKGROUND_COLOR = 'FF1A65A6'.freeze
      HEADER_FONT_COLOR = 'FFFFFFFF'.freeze
      HEADER_FONT_SIZE = 14
      ROW_FONT_SIZE = 12
      REPLACE_LINK_ROW_HEIGHT = 54
      CELL_INDENT = 1
      TABLE_NAME = 'Your_commodities_from_your_commodity_watch_list'.freeze
      TABLE_START_ROW = 7
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
          fg_color: HEADER_FONT_COLOR,
          bg_color: HEADER_BACKGROUND_COLOR,
          alignment: { horizontal: :left, vertical: :center },
        )
        sheet.add_row(HEADERS, style: [header_style] * HEADERS.length)
      end

      def add_intro_rows(sheet, workbook)
        title_style = workbook.styles.add_style(b: true, sz: 24)
        label_style = workbook.styles.add_style(b: true, alignment: { vertical: :top })
        instruction_style = workbook.styles.add_style(alignment: { wrap_text: true, vertical: :top })
        text_style = workbook.styles.add_style(alignment: { vertical: :top })
        upload_link_style = workbook.styles.add_style(
          b: true,
          sz: ROW_FONT_SIZE,
          u: true,
          fg_color: 'FFFFFF',
          bg_color: 'FF0F7A52',
          border: { style: :thin, color: 'FF083D29', edges: [:bottom] },
          alignment: {
            horizontal: :center,
            vertical: :center,
            indent: 1,
          },
        )

        sheet.add_row(['Your commodities'], style: [title_style])

        instructions_text = "All your active and expired codes, as well as errors are listed on this spreadsheet.\n\nYou can edit, add and remove codes from this spreadsheet.\n\nThis spreadsheet is designed with the codes in column A, so you can upload it to update your commodity watch list."
        sheet.add_row(['Instructions:', instructions_text], style: [label_style, instruction_style])

        downloaded_on = TimeMachine.now { Time.zone.today.strftime('%d/%m/%Y') }
        sheet.add_row(['Date downloaded:', downloaded_on], style: [label_style, text_style])

        sheet.add_row([''])

        upload_row = sheet.add_row(['Replace all commodities (upload)'], style: [upload_link_style])
        upload_row.height = REPLACE_LINK_ROW_HEIGHT
        sheet.add_hyperlink(location: REPLACE_ALL_COMMODITIES_UPLOAD_URL, ref: upload_row.cells[0])

        sheet.add_row([''])
      end

      def add_rows(sheet, workbook)
        report_rows.each do |row|
          sheet.add_row(
            [row[:code], description_cell_value(row), row[:status]],
            types: [:string, nil, :string],
            style: row_styles(workbook, row[:status]),
          )
        end
      end

      def add_table_styling(sheet)
        return if report_rows.empty?

        last_row = TABLE_START_ROW + report_rows.length
        sheet.add_table(
          "A#{TABLE_START_ROW}:C#{last_row}",
          name: TABLE_NAME,
          style_info: {
            name: 'TableStyleMedium2',
            show_first_column: false,
            show_last_column: false,
            show_row_stripes: true,
            show_column_stripes: false,
          },
        )
      end

      def set_column_widths(sheet)
        sheet.column_widths(36, 90, 24)
      end

      def report_rows
        @report_rows ||= begin
          all_codes = (active_codes + expired_codes + invalid_codes).uniq.sort
          valid_codes = all_codes - invalid_codes
          descriptions = load_classification_descriptions(valid_codes)
          heading_descriptions = load_heading_descriptions(valid_codes)
          statuses = status_by_code

          all_codes.map do |code|
            status = statuses[code]

            {
              code: code,
              description: descriptions[code].to_s,
              heading_description: heading_descriptions[code].to_s,
              status: status,
            }
          end
        end
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
          styles[:description],
          styles.fetch(status),
        ]
      end

      def table_styles(workbook)
        @table_styles ||= {
          commodity_code: workbook.styles.add_style(
            b: true,
            sz: ROW_FONT_SIZE,
            alignment: { horizontal: :left, vertical: :top, indent: CELL_INDENT },
          ),
          description: workbook.styles.add_style(
            sz: ROW_FONT_SIZE,
            alignment: { horizontal: :left, vertical: :top, indent: CELL_INDENT, wrap_text: true },
          ),
          text: workbook.styles.add_style(
            sz: ROW_FONT_SIZE,
            alignment: { horizontal: :left, vertical: :top, indent: CELL_INDENT },
          ),
          ACTIVE => workbook.styles.add_style(
            b: true,
            sz: ROW_FONT_SIZE,
            bg_color: ACTIVE_BACKGROUND_COLOR,
            fg_color: ACTIVE_FONT_COLOR,
            alignment: { horizontal: :left, vertical: :top, indent: CELL_INDENT },
          ),
          EXPIRED => workbook.styles.add_style(
            b: true,
            sz: ROW_FONT_SIZE,
            bg_color: EXPIRED_BACKGROUND_COLOR,
            fg_color: EXPIRED_FONT_COLOR,
            alignment: { horizontal: :left, vertical: :top, indent: CELL_INDENT },
          ),
          ERROR_FROM_UPLOAD => workbook.styles.add_style(
            b: true,
            sz: ROW_FONT_SIZE,
            bg_color: ERROR_FROM_UPLOAD_BACKGROUND_COLOR,
            fg_color: ERROR_FROM_UPLOAD_FONT_COLOR,
            alignment: { horizontal: :left, vertical: :top, indent: CELL_INDENT },
          ),
        }
      end

      def description_cell_value(row)
        return "Not applicable\n" if row[:status] == ERROR_FROM_UPLOAD
        return "#{row[:description]}\n" if row[:heading_description].blank?

        rich_text = Axlsx::RichText.new
        rich_text.add_run(row[:heading_description], b: true)
        rich_text.add_run("\n#{row[:description]}") if row[:description].present?
        rich_text
      end

      def load_classification_descriptions(codes)
        return {} if codes.empty?

        descriptions = load_latest_formatted_descriptions(codes)
        other_codes = descriptions.select { |_code, description| other_description?(description) }.keys

        return descriptions if other_codes.empty?

        descriptions.merge(load_other_classification_descriptions(other_codes))
      end

      def load_other_classification_descriptions(codes)
        latest_commodities = GoodsNomenclature
          .where(goods_nomenclatures__goods_nomenclature_item_id: codes)
          .eager(
            :goods_nomenclature_descriptions,
            { ancestors: :goods_nomenclature_descriptions },
            { heading: :goods_nomenclature_descriptions },
          )
          .all
          .group_by(&:goods_nomenclature_item_id)
          .transform_values do |records|
            records.max_by { |record| [record.validity_start_date.to_s, record.goods_nomenclature_sid] }
          end

        latest_commodities.transform_values do |commodity|
          html_to_plain_text(commodity.classification_description.to_s)
        end
      end

      def load_heading_descriptions(codes)
        heading_codes = codes.map { |code| heading_code_for(code) }.uniq
        descriptions_by_heading_code = load_latest_formatted_descriptions(heading_codes)

        codes.index_with { |code| descriptions_by_heading_code[heading_code_for(code)].to_s }
      end

      def load_latest_formatted_descriptions(codes)
        return {} if codes.empty?

        GoodsNomenclatureDescription
          .where(goods_nomenclature_item_id: codes)
          .order(Sequel.desc(:goods_nomenclature_description_period_sid))
          .all
          .each_with_object({}) do |record, descriptions|
            next if descriptions.key?(record.goods_nomenclature_item_id)

            descriptions[record.goods_nomenclature_item_id] = html_to_plain_text(record.formatted_description.to_s)
          end
      end

      def heading_code_for(commodity_code)
        "#{commodity_code.to_s.first(4)}000000"
      end

      def html_to_plain_text(text)
        with_line_breaks = text.to_s.gsub(%r{<br\s*/?>}i, "\n")
        sanitized_text = Rails::HTML5::FullSanitizer.new.sanitize(with_line_breaks)
        CGI.unescapeHTML(sanitized_text)
      end

      def other_description?(description)
        description.to_s.match?(/^other$/i)
      end
    end
  end
end
