# frozen_string_literal: true

module Api
  module Admin
    module SearchExport
      class WorkbooksController < AdminController
        def create
          return head :not_found unless TradeTariffBackend.uk?

          range = ::SearchExport::DateRange.parse(from: params[:from], to: params[:to])
          if ::SearchExport::Workbook.candidate_count(from: range.from, to: range.to) > ::SearchExport::Workbook::MAX_ROWS
            return render json: error_response('Date range too large', 'Shorten the date range. This export is limited to 200,000 journeys.', :unprocessable_content),
                          status: :unprocessable_content
          end

          export = ::SearchExport::WorkbookExport.create(
            service: TradeTariffBackend.service,
            from_date: range.from,
            to_date: range.to,
            status: ::SearchExport::WorkbookExport::QUEUED,
            whodunnit: TradeTariffRequest.whodunnit,
          )
          ::SearchExport::WorkbookWorker.perform_async(export.id)
          render json: payload(export), status: :accepted
        rescue ::SearchExport::DateRange::InvalidRange => e
          render json: error_response('Invalid date range', e.message, :bad_request), status: :bad_request
        end

        def show
          return head :not_found unless TradeTariffBackend.uk?

          export = ::SearchExport::WorkbookExport.where(service: TradeTariffBackend.service).with_pk(params[:id])
          return head :not_found unless export

          render json: payload(export)
        end

        def download
          return head :not_found unless TradeTariffBackend.uk?

          export = ::SearchExport::WorkbookExport.where(service: TradeTariffBackend.service).with_pk(params[:id])
          return head :not_found unless export&.ready?

          send_data export.file,
                    filename: "classifier-workbook-#{export.from_date}-#{export.to_date}.xlsx",
                    type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                    disposition: 'attachment'
        end

      private

        def payload(export)
          {
            data: {
              id: export.id.to_s,
              type: 'search_export_workbook',
              attributes: {
                status: export.status,
                from: export.from_date.iso8601,
                to: export.to_date.iso8601,
                omitted_count: export.omitted_count,
                row_count: export.row_count,
                error: export.error_message,
              },
            },
          }
        end

        def error_response(title, detail, status)
          { errors: [{ status: Rack::Utils.status_code(status).to_s, title:, detail: }] }
        end
      end
    end
  end
end
