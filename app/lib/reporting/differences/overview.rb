module Reporting
  class Differences
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
            },
            'Commodities in UK tariff, but missing from EU tariff' => {
              description: 'As of as_of, these commodity codes are in the UK tariff but not in the EU tariff.',
              worksheet_name: 'Commodities in UK, not in EU',
            },
            'Commodities where indentation is different between the UK and EU tariffs' => {
              description: 'Indentation is crucial to get right to avoid measures being unexpectedly assigned or omitted.',
              worksheet_name: 'Indentation differences',
            },
            'Commodities where the hierarchy is different between the UK and EU tariffs' => {
              description: 'This tends to be linked to or caused by missing or unwanted codes or indentation issues.',
              worksheet_name: 'Hierarchy differences',
            },
            'Commodities where the end line (declarable) status is different between the UK and EU tariffs' => {
              description: 'End lines (or declarable) codes need to align between the two tariffs, or there will be issues on the XI dual tariff',
              worksheet_name: 'End line differences',
            },
            'Commodities where the start date is different between the UK and EU tariffs' => {
              description: 'Not crucial, but worth checking in case there are wild differences: the EU has made mistakes in this area',
              worksheet_name: 'Start date differences',
            },
            'Commodities where the end date is different between the UK and EU tariffs' => {
              description: '',
              worksheet_name: 'End date differences',
            },
          },
        },
        'Duty and measure-related anomalies' => {
          section_colour: '48C83F',
          worksheets: {
            'Missing MFN (third-country) duties' => {
              description: 'Commodities, as of as_of, where there is no third-country duty.',
              worksheet_name: 'MFN missing',
            },
            'Duplicated UK MFN duties' => {
              description: 'More than one MFN is on a single commodity code',
              worksheet_name: 'Duplicate MFNs',
            },
            'Misapplied action codes' => {
              description: 'An action code that should be negative is positive, or vice versa.',
              worksheet_name: 'Misapplied action codes',
            },
            'ME32 candidates' => {
              description: 'There may be no overlap in time with other measure occurrences with a goods code in the same nomenclature hierarchy which references the same measure type, geo area, order number and additional code.',
              worksheet_name: 'ME32 candidates',
            },
            'Incomplete conditions' => {
              description: 'These are conditions where the measurement unit is missing, rendering the measure invalid.',
              worksheet_name: 'Incomplete conditions',
            },
            'Omitted duties' => {
              description: 'Comparing preferential and suspension measures that are present now (as_of) versus those that were present a year before. Ukraine-related measures are omitted, as these changed by design. Not all items listed here will be issues.',
              worksheet_name: 'Omitted duties',
            },
            'Seasonal duties' => {
              description: 'Seasonal duties that should be in place (according to the reference documents) but cannot be found',
              worksheet_name: 'Seasonal duties',
            },
          },
        },
        'VAT-related anomalies' => {
          section_colour: '666666',
          worksheets: {
            'Missing VAT rates' => {
              description: 'Commodities, as of as_of, where there is no VAT rate.',
              worksheet_name: 'VAT-related anomalies',
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
            },
            'Quota measures - insufficient definition coverage' => {
              description: 'These are measures where, at some point, they will start to become non-operational or illusory as there is no equivalent quota definition associated with it for its full extent',
              worksheet_name: 'Measure quot def coverage',
            },
            'Self-referential quota associations' => {
              description: 'These are quotas where a parent (main) definition refers to itself as well as to its child (sub) definitions. These are very problematic for EQ type associations, and will result in improper quota balance decrementation, but less so for NM type associations. Past definitions are now omitted',
              worksheet_name: 'Self-referential associations',
            },
            'Quota exclusion misalignment' => {
              description: 'A FCFS quota is made up of both measures and quota order numbers. Each point to origins, and each of these origins may have exclusions. They need to match to provide a reliable experience for traders.',
              worksheet_name: 'Exclusion misalignment',
            },
          },
        },
        'Supplementary unit-related anomalies' => {
          section_colour: '611062',
          worksheets: {
            'Supplementary units present on the EU tariff, but not on the UK tariff' => {
              description: 'May cause issues for Northern Ireland trade',
              worksheet_name: 'Supp units on EU not UK',
            },
            'Supplementary units present on the UK tariff, but not on the EU tariff' => {
              description: 'May cause issues for Northern Ireland trade',
              worksheet_name: 'Supp units on UK not EU',
            },
            'Supplementary units that should be present' => {
              description: 'Excise etc. may require a supp unit that is not provided',
              worksheet_name: 'Supp unit candidates',
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
            },
          },
        },
      }.freeze

      CELL_TYPES = Array.new(4, :string).freeze

      COLUMN_WIDTHS = [
        4,  # Section square
        90, # Dashboard section/worksheet
        10, # Count
        90, # About this metric
        10, # View issues
      ].freeze

      def initialize(report)
        @report = report
      end

      def add_worksheet
        dashboard_styles = {
          'C02814' => workbook.styles.add_style(bg_color: 'C02814', fg_color: 'FFFFFF'),
          '48C83F' => workbook.styles.add_style(bg_color: '48C83F', fg_color: 'FFFFFF'),
          '666666' => workbook.styles.add_style(bg_color: '666666', fg_color: 'FFFFFF'),
          '311493' => workbook.styles.add_style(bg_color: '311493', fg_color: 'FFFFFF'),
          'CACC43' => workbook.styles.add_style(bg_color: 'CACC43', fg_color: 'FFFFFF'),
          '611062' => workbook.styles.add_style(bg_color: '611062', fg_color: 'FFFFFF'),
          '000000' => workbook.styles.add_style(bg_color: '000000', fg_color: 'FFFFFF'),
          'header_section' => workbook.styles.add_style(
            b: true,
            alignment: {
              horizontal: :left,
              vertical: :top,
              wrap_text: true,
            },
            sz: 14,
            font_name: 'Calibri',
          ),
          'header_count' => workbook.styles.add_style(
            b: true,
            alignment: {
              horizontal: :center,
              vertical: :top,
            },
            sz: 14,
            font_name: 'Calibri',
          ),
          'header_about' => workbook.styles.add_style(
            b: true,
            alignment: {
              horizontal: :left,
              vertical: :top,
              wrap_text: true,
            },
            sz: 14,
            font_name: 'Calibri',
          ),
          'header_view' => workbook.styles.add_style(
            b: true,
            alignment: {
              horizontal: :center,
              vertical: :top,
            },
            sz: 11,
            font_name: 'Calibri',
          ),
        }

        workbook.add_worksheet(name:) do |sheet|
          OVERVIEW_SECTION_CONFIG.each do |section, config|
            sheet.add_row([nil, section, 'Count', 'About this metric', nil])
            colour = config[:section_colour]

            section_header_row = sheet.rows.last
            section_header_row[0].style = dashboard_styles[colour]
            section_header_row[1].style = dashboard_styles['header_section']
            section_header_row[2].style = dashboard_styles['header_count']
            section_header_row[3].style = dashboard_styles['header_about']
            section_header_row[4].style = dashboard_styles['header_view']

            config[:worksheets].each do |worksheet, worksheet_config|
              report_date = report.as_of.to_date.to_fs(:govuk)
              worksheet_description = worksheet_config[:description].sub('as_of', report_date)
              worksheet_name = worksheet_config[:worksheet_name]

              sheet.add_row(
                [
                  nil,
                  worksheet,
                  report.overview_counts[worksheet_name],
                  worksheet_description,
                  'View issues',
                  nil,
                ],
                types: CELL_TYPES,
              )
              worksheet_row = sheet.rows.last

              worksheet_row[1].style = regular_style
              worksheet_row[2].style = centered_style
              worksheet_row[3].style = regular_style

              sheet.add_hyperlink(
                location: "'#{worksheet_name}'!A1",
                target: :sheet,
                ref: worksheet_row[4].r,
              )
            end

            sheet.add_row([])
          end

          sheet.column_widths(*COLUMN_WIDTHS)
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
