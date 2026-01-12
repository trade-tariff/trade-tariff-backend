module Reporting
  class Differences
    module Renderers
      class Overview
        delegate :workbook,
                 :regular_style,
                 :bold_style,
                 :centered_style,
                 to: :report

        WORKSHEET_NAME = 'Overview'.freeze

        OVERVIEW_SECTION_CONFIG = {
          'Commodity code-related anomalies' => {
            section_colour: 'C02814',
            worksheets: {
              'Commodities in EU tariff, but missing from UK tariff' => {
                description: 'As of as_of, these commodity codes are in the EU tariff but not in the UK tariff.',
                worksheet_name: 'Commodities in EU, not in UK',
                new_items_formula: "=COUNTIF('Commodities in EU, not in UK'!I:I, \"Yes\")",
              },
              'Commodities in UK tariff, but missing from EU tariff' => {
                description: 'As of as_of, these commodity codes are in the UK tariff but not in the EU tariff.',
                worksheet_name: 'Commodities in UK, not in EU',
                new_items_formula: "=COUNTIF('Commodities in UK, not in EU'!I:I, \"Yes\")",
              },
              'Commodities where indentation is different between the UK and EU tariffs' => {
                description: 'Indentation is crucial to get right to avoid measures being unexpectedly assigned or omitted.',
                worksheet_name: 'Indentation differences',
                new_items_formula: "=COUNTIF('Indentation differences'!D:D, \"Yes\")",
              },
              'Commodities where the hierarchy is different between the UK and EU tariffs' => {
                description: 'This tends to be linked to or caused by missing or unwanted codes or indentation issues.',
                worksheet_name: 'Hierarchy differences',
                new_items_formula: "=COUNTIF('Hierarchy differences'!D:D, \"Yes\")",
              },
              'Commodities where the end line (declarable) status is different between the UK and EU tariffs' => {
                description: 'End lines (or declarable) codes need to align between the two tariffs, or there will be issues on the XI dual tariff',
                worksheet_name: 'End line differences',
                new_items_formula: "=COUNTIF('End line differences'!D:D, \"Yes\")",
              },
              'Commodities where the start date is different between the UK and EU tariffs' => {
                description: 'Not crucial, but worth checking in case there are wild differences: the EU has made mistakes in this area',
                worksheet_name: 'Start date differences',
                new_items_formula: "=COUNTIF('Start date differences'!D:D, \"Yes\")",
              },
              'Commodities where the end date is different between the UK and EU tariffs' => {
                description: '',
                worksheet_name: 'End date differences',
                new_items_formula: "=COUNTIF('End date differences'!D:D, \"Yes\")",
              },
            },
          },
          'Duty and measure-related anomalies' => {
            section_colour: '48C83F',
            worksheets: {
              'Missing MFN (third-country) duties' => {
                description: 'Commodities, as of as_of, where there is no third-country duty.',
                worksheet_name: 'MFN missing',
                new_items_formula: "=COUNTIF('MFN missing'!C:C, \"Yes\")",
              },
              'Duplicated UK MFN duties' => {
                description: 'More than one MFN is on a single commodity code',
                worksheet_name: 'Duplicate MFNs',
                new_items_formula: "=COUNTIF('Duplicate MFNs'!K:K, \"Yes\")",
              },
              'Misapplied action codes' => {
                description: 'An action code that should be negative is positive, or vice versa.',
                worksheet_name: 'Misapplied action codes',
                new_items_formula: "=COUNTIF('Misapplied action codes'!K:K, \"Yes\")",
              },
              'ME32 candidates' => {
                description: 'There may be no overlap in time with other measure occurrences with a goods code in the same nomenclature hierarchy which references the same measure type, geo area, order number and additional code.',
                worksheet_name: 'ME32 candidates',
                new_items_formula: "=COUNTIF('ME32 candidates'!F:F, \"Yes\")",
              },
              'Incomplete conditions' => {
                description: 'These are conditions where the measurement unit is missing, rendering the measure invalid.',
                worksheet_name: 'Incomplete conditions',
                new_items_formula: "=COUNTIF('Incomplete conditions'!I:I, \"Yes\")",
              },
              'Omitted duties' => {
                description: 'Comparing preferential and suspension measures that are present now (as_of) versus those that were present a year before. Ukraine-related measures are omitted, as these changed by design. Not all items listed here will be issues.',
                worksheet_name: 'Omitted duties',
                new_items_formula: "=COUNTIF('Omitted duties'!G:G, \"Yes\")",
              },
              'Seasonal duties' => {
                description: 'Seasonal duties that should be in place (according to the reference documents) but cannot be found',
                worksheet_name: 'Seasonal duties',
                new_items_formula: "=COUNTIF('Seasonal duties'!G:G, \"Yes\")",
              },
            },
          },
          'VAT-related anomalies' => {
            section_colour: '666666',
            worksheets: {
              'Missing VAT rates' => {
                description: 'Commodities, as of as_of, where there is no VAT rate.',
                worksheet_name: 'VAT missing',
                new_items_formula: "=COUNTIF('VAT missing'!C:C, \"Yes\")",
              },
            },
          },
          # 'Commodity code description-related anomalies' => {
          #   section_colour: '311493',
          #   worksheets: {
          #     # 'Total number of differences in commodity code descriptions' => 'Covers all difference types - does not imply there is an issue',
          #     # 'Descriptions - UK description is missing' => 'Indentation is crucial to get right to avoid measures being unexpectedly assigned or omitted.',
          #     # 'Descriptions - Typo or small difference' => 'This tends to be linked to or caused by missing or unwanted codes or indentation issues.',
          #   },
          # },
          'Quota-related anomalies' => {
            section_colour: 'CACC43',
            worksheets: {
              'Quotas missing origins' => {
                description: 'This tends to be linked to or caused by missing or unwanted codes or indentation issues.',
                worksheet_name: 'Quota with no origins',
                new_items_formula: "=COUNTIF('Quota with no origins'!E:E, \"Yes\")",
              },
              'Quota measures - insufficient definition coverage' => {
                description: 'These are measures where, at some point, they will start to become non-operational or illusory as there is no equivalent quota definition associated with it for its full extent',
                worksheet_name: 'Measure quot def coverage',
                new_items_formula: "=COUNTIF('Measure quot def coverage'!G:G, \"Yes\")",
              },
              'Self-referential quota associations' => {
                description: 'These are quotas where a parent (main) definition refers to itself as well as to its child (sub) definitions. These are very problematic for EQ type associations, and will result in improper quota balance decrementation, but less so for NM type associations. Past definitions are now omitted',
                worksheet_name: 'Self-referential associations',
                new_items_formula: "=COUNTIF('Self-referential associations'!K:K, \"Yes\")",
              },
              'Quota exclusion misalignment' => {
                description: 'A FCFS quota is made up of both measures and quota order numbers. Each point to origins, and each of these origins may have exclusions. They need to match to provide a reliable experience for traders.',
                worksheet_name: 'Exclusion misalignment',
                new_items_formula: "=COUNTIF('Exclusion misalignment'!E:E, \"Yes\")",
              },
            },
          },
          'Supplementary unit-related anomalies' => {
            section_colour: '611062',
            worksheets: {
              'Supplementary units present on the EU tariff, but not on the UK tariff' => {
                description: 'May cause issues for Northern Ireland trade',
                worksheet_name: 'Supp units on EU not UK',
                new_items_formula: "=COUNTIF('Supp units on EU not UK'!F:F, \"Yes\")",
              },
              'Supplementary units present on the UK tariff, but not on the EU tariff' => {
                description: 'May cause issues for Northern Ireland trade',
                worksheet_name: 'Supp units on UK not EU',
                new_items_formula: "=COUNTIF('Supp units on UK not EU'!F:F, \"Yes\")",
              },
              'Supplementary units that should be present' => {
                description: 'Excise etc. may require a supp unit that is not provided',
                worksheet_name: 'Supp unit candidates',
                new_items_formula: "=COUNTIF('Supp unit candidates'!C:C, \"Yes\")",
              },
            },
          },
          'Suspension-related anomalies' => {
            section_colour: '000000',
            worksheets: {
              # 'Unpaired additional codes' => 'This indicates that there is a single additional code, not an MFN plus a suspension additional code on a commodity. It's not certain if this will cause an issue, but it creates additional trader effort for no reason.',
              'ME16 candidates' => {
                description: 'This indicates that there are comm codes where a duty exists both with and without additional codes, which breaks ME16',
                worksheet_name: 'ME16 candidates',
                new_items_formula: "=COUNTIF('ME16 candidates'!C:C, \"Yes\")",
              },
            },
          },
        }.freeze

        COLUMN_WIDTHS = [
          4,  # Section square
          90, # Dashboard section/worksheet
          10, # Count
          12, # New Items
          90, # About this metric
          10, # View issues
        ].freeze

        def initialize(report)
          @report = report
        end

        def add_worksheet(data) # rubocop:disable Lint/UnusedMethodArgument
          dashboard_styles = {
            'C02814' => workbook.add_format(bg_color: 'C02814', fg_color: 'FFFFFF'),
            '48C83F' => workbook.add_format(bg_color: '48C83F', fg_color: 'FFFFFF'),
            '666666' => workbook.add_format(bg_color: '666666', fg_color: 'FFFFFF'),
            '311493' => workbook.add_format(bg_color: '311493', fg_color: 'FFFFFF'),
            'CACC43' => workbook.add_format(bg_color: 'CACC43', fg_color: 'FFFFFF'),
            '611062' => workbook.add_format(bg_color: '611062', fg_color: 'FFFFFF'),
            '000000' => workbook.add_format(bg_color: '000000', fg_color: 'FFFFFF'),
            'header_section' => workbook.add_format(
              align: { h: :left, v: :top },
              bold: true,
              font_name: 'Calibri',
              font_size: 14,
              text_wrap: true,
            ),
            'header_count' => workbook.add_format(
              align: { h: :center, v: :top },
              bold: true,
              font_name: 'Calibri',
              font_size: 14,
            ),
            'header_about' => workbook.add_format(
              align: { h: :left, v: :top },
              bold: true,
              font_name: 'Calibri',
              font_size: 14,
              text_wrap: true,
            ),
            'header_view' => workbook.add_format(
              align: { h: :center, v: :top },
              bold: true,
              font_name: 'Calibri',
              font_size: 11,
            ),
          }

          workbook.add_worksheet(name:) do |sheet|
            OVERVIEW_SECTION_CONFIG.each do |section, config|
              colour = config[:section_colour]

              sheet.append_row(
                [
                  nil,
                  section,
                  'Count',
                  'New Items',
                  'About this metric',
                  nil,
                ],
                [
                  dashboard_styles[colour],
                  dashboard_styles['header_section'],
                  dashboard_styles['header_count'],
                  dashboard_styles['header_count'],
                  dashboard_styles['header_about'],
                  dashboard_styles['header_view'],
                ],
              )

              config[:worksheets].each do |worksheet, worksheet_config|
                report_date = report.as_of.to_date.to_fs(:govuk)
                worksheet_description = worksheet_config[:description].sub('as_of', report_date)
                worksheet_name = worksheet_config[:worksheet_name]

                sheet.append_row(
                  [
                    nil,
                    worksheet,
                    "=COUNTA('#{worksheet_name}'!A2:A1048576)",
                    worksheet_config.fetch(:new_items_formula, nil),
                    worksheet_description,
                    FastExcel::URL.new("internal:#{worksheet_name}!A1"),
                    nil,
                  ],
                  [
                    nil,
                    regular_style,
                    centered_style,
                    centered_style,
                    regular_style,
                    centered_style,
                    nil,
                  ],
                )

                sheet.write_string(5, 1, 'View issues', nil)
              end

              sheet.add_row([])
            end

            COLUMN_WIDTHS.each_with_index do |width, index|
              sheet.set_column_width(index, width)
            end
          end

          workbook.worksheets.rotate!(-1)
        end

        private

        attr_reader :report

        def name
          WORKSHEET_NAME
        end
      end
    end
  end
end
