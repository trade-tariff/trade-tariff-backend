# frozen_string_literal: true

module Api
  module Admin
    module SearchExport
      class WorkbooksController < AdminController
        def create
          return head :not_found unless TradeTariffBackend.uk?

          range = ::SearchExport::DateRange.parse(from: params[:from], to: params[:to])
          export = ::SearchExport::WorkbookExport.create(from_date: range.from, to_date: range.to)
          unless ::SearchExport::WorkbookWorker.perform_async(export.id)
            export.delete
            return unavailable('The workbook could not be queued. Please try again.')
          end
          render json: payload(export), status: :accepted
        rescue ::SearchExport::DateRange::InvalidRange => e
          render json: error_response('Invalid date range', e.message, :bad_request), status: :bad_request
        rescue ::SearchExport::WorkbookExport::Busy => e
          unavailable(e.message)
        rescue RedisClient::Error
          unavailable('The workbook service is unavailable. Please try again.')
        end

        def show
          return head :not_found unless TradeTariffBackend.uk?

          export = ::SearchExport::WorkbookExport.find(params[:id])
          return head :not_found unless export

          export.expire_if_stale!
          result = payload(export)
          return head :not_found unless result

          render json: result
        rescue RedisClient::Error
          unavailable('The workbook service is unavailable. Please try again.')
        end

        def download
          return head :not_found unless TradeTariffBackend.uk?

          export = ::SearchExport::WorkbookExport.find(params[:id])
          metadata = export&.payload
          return head :not_found unless metadata && metadata['status'] == 'ready'

          bytes = export.file
          return head :not_found unless bytes

          send_data bytes,
                    filename: "classifier-workbook-#{metadata.fetch('from')}-#{metadata.fetch('to')}.xlsx",
                    type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                    disposition: 'attachment'
        rescue RedisClient::Error
          unavailable('The workbook service is unavailable. Please try again.')
        end

      private

        def payload(export)
          stored = export.payload
          return unless stored

          { data: { id: export.id, type: 'search_export_workbook', attributes: stored.slice('status', 'from', 'to', 'omitted_count', 'row_count', 'error') } }
        end

        def unavailable(message)
          render json: error_response('Workbook unavailable', message, :service_unavailable), status: :service_unavailable
        end

        def error_response(title, detail, status)
          { errors: [{ status: Rack::Utils.status_code(status).to_s, title:, detail: }] }
        end
      end
    end
  end
end
