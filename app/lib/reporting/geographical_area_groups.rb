module Reporting
  class GeographicalAreaGroups
    include Reporting::Reportable

    HEADER_ROW = %w[
      parent_id
      parent_description
      child_id
      child_description
    ].freeze

    COLUMN_WIDTHS = [
      20, # parent_id
      75, # parent_description
      20, # child_id
      75, # child_description
    ].freeze

    class PresentedGroup < WrapDelegator
      def parent_id
        geographical_area_id
      end

      def parent_description
        description
      end
    end

    class PresentedChild < WrapDelegator
      def child_id
        geographical_area_id
      end

      def child_description
        description
      end
    end

    class << self
      def generate
        with_report_logging do
          workbook = open_workbook
          bold_format = instrument_report_step('add_format') { workbook.add_format(bold: true) }
          worksheet = setup_worksheet(workbook, bold_format)
          rows = instrument_report_step('load_rows') do
            geographical_area_group_and_children
          end

          rows_written = append_rows(worksheet, rows)

          log_report_metric('rows_written', rows_written)

          workbook_data = close_workbook(workbook, rows_written)

          log_report_metric('output_bytes', workbook_data.bytesize) if workbook_data
          upload(workbook_data, rows_written) if Rails.env.production?
        end
      end

    private

      def open_workbook
        instrument_report_step('open_workbook') do
          if Rails.env.development?
            FileUtils.rm(filename) if File.exist?(filename)
            FastExcel.open(filename, constant_memory: true)
          else
            FastExcel.open(constant_memory: true)
          end
        end
      end

      def setup_worksheet(workbook, bold_format)
        instrument_report_step('setup_worksheet') do
          sheet = workbook.add_worksheet(Time.zone.today.iso8601)
          configure_worksheet(sheet, bold_format)
          sheet
        end
      end

      def configure_worksheet(sheet, bold_format)
        COLUMN_WIDTHS.each_with_index do |width, index|
          sheet.set_column_width(index, width)
        end

        sheet.append_row(HEADER_ROW, bold_format)
        sheet.freeze_panes(1, 0)
        sheet.autofilter(0, 1, 1, 4)
      end

      def append_rows(worksheet, rows)
        instrument_report_step('append_rows') do
          rows.each do |group, child|
            worksheet.append_row(build_row_for(group, child))
          end

          rows.size
        end
      end

      def close_workbook(workbook, rows_written)
        instrument_report_step('close_workbook', rows_written:) do
          workbook.close
          Rails.env.production? ? workbook.read_string : nil
        end
      end

      def upload(workbook_data, rows_written)
        instrument_report_step('upload', rows_written:, output_bytes: workbook_data.bytesize) do
          object.put(
            body: workbook_data,
            content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          )
        end
      end

      def build_row_for(group, child)
        HEADER_ROW.map do |header|
          if group.respond_to?(header)
            group.public_send(header)
          else
            child.public_send(header)
          end
        end
      end

      def geographical_area_group_and_children
        TimeMachine.now do
          GeographicalArea
            .groups
            .actual
            .eager(
              :geographical_area_descriptions,
              contained_geographical_areas: :geographical_area_descriptions,
            )
            .all
            .flat_map do |group|
              group.contained_geographical_areas.map do |child|
                [PresentedGroup.new(group), PresentedChild.new(child)]
              end
            end
        end
      end

      def object_key
        "#{service}/reporting/#{year}/#{month}/#{day}/geographical_area_groups_#{service}_#{now.strftime('%Y_%m_%d')}.xlsx"
      end

      def filename
        File.basename(object_key)
      end
    end
  end
end
