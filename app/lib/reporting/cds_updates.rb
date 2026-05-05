module Reporting
  class CdsUpdates
    include Reporting::Reportable

    HEADER_ROW = ['Date of the file', 'Downloaded Time', 'Updated Time', 'Status'].freeze
    COLUMN_WIDTHS = [30, 50, 50, 20].freeze

    class << self
      def generate
        with_report_logging do
          workbook = instrument_report_step('open_workbook') do
            if Rails.env.development?
              FileUtils.rm(filename) if File.exist?(filename)

              FastExcel.open(
                filename,
                constant_memory: true,
              )
            else
              FastExcel.open(
                constant_memory: true,
              )
            end
          end

          bold_format = instrument_report_step('add_format') do
            workbook.add_format(bold: true)
          end

          worksheet = instrument_report_step('setup_worksheet') do
            sheet = workbook.add_worksheet(Time.zone.today.iso8601)

            COLUMN_WIDTHS.each_with_index do |width, index|
              sheet.set_column_width(index, width)
            end

            sheet.append_row(HEADER_ROW, bold_format)
            sheet.freeze_panes(1, 0)
            sheet
          end

          rows = instrument_report_step('load_rows') do
            cds_updates
          end

          rows_written = instrument_report_step('append_rows') do
            count = 0

            rows.each do |update|
              build_rows_for(update).each do |row|
                worksheet.append_row(row)
                count += 1
              end
            end

            count
          end

          log_report_metric('rows_written', rows_written)

          workbook_data = instrument_report_step('close_workbook', rows_written:) do
            workbook.close
            Rails.env.production? ? workbook.read_string : nil
          end

          if workbook_data
            log_report_metric('output_bytes', workbook_data.bytesize)

            instrument_report_step('upload', rows_written:, output_bytes: workbook_data.bytesize) do
              object.put(
                body: workbook_data,
                content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              )
            end
          end
        end
      end

      private

      def cds_updates
        previous_month = Time.zone.today.last_month
        start_of_previous_month = previous_month.beginning_of_month
        start_of_current_month = previous_month.next_month.beginning_of_month

        TariffSynchronizer::CdsUpdate
          .exclude(filename: nil)
          .where(Sequel[:created_at] >= start_of_previous_month)
          .where(Sequel[:created_at] < start_of_current_month)
          .eager(state_changes: ->(association_dataset) { association_dataset.order(:created_at) })
          .reverse_order(:created_at)
          .all
      end

      def build_rows_for(update)
        state_changes = update.state_changes
        return [default_row_for(update)] if state_changes.empty?

        state_changes.map do |change|
          [
            update.issue_date&.iso8601,
            update.created_at&.iso8601,
            change.created_at&.iso8601,
            change.to_state,
          ]
        end
      end

      def default_row_for(update)
        [
          update.issue_date&.iso8601,
          update.created_at&.iso8601,
          update.updated_at&.iso8601,
          update.state,
        ]
      end

      def object_key
        "#{service}/reporting/#{year}/#{month}/#{day}/cds_updates_#{service}_#{now.strftime('%Y_%m_%d')}.xlsx"
      end

      def filename
        File.basename(object_key)
      end
    end
  end
end
