# frozen_string_literal: true

module Api
  module Admin
    module SearchExport
      class WorkbooksController < AdminController
        before_action :find_export, only: %i[show download]
        rescue_from RedisClient::Error do
          unavailable('The workbook service is unavailable. Please try again.')
        end

        def create
          range = ::SearchExport::DateRange.parse(from: params[:from], to: params[:to])
          @export = ::SearchExport::WorkbookExport.create(from_date: range.from, to_date: range.to)
          if @export.newly_created? && !enqueue_export
            @export.delete
            return unavailable('The workbook could not be queued. Please try again.')
          end
          render_export(status: :accepted)
        rescue ::SearchExport::DateRange::InvalidRange => e
          render json: error_response('Invalid date range', e.message, :bad_request), status: :bad_request
        end

        def show
          render_export
        end

        def download
          metadata = @export.payload
          return head :not_found unless metadata && metadata['status'] == 'ready'

          bytes = @export.file
          return head :not_found unless bytes

          send_data bytes,
                    filename: "classifier-workbook-#{metadata.fetch('from')}-#{metadata.fetch('to')}.xlsx",
                    type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                    disposition: 'attachment'
        end

      private

        def enqueue_export
          ::SearchExport::WorkbookWorker.perform_async(@export.id)
        rescue RedisClient::Error
          @export.delete
          raise
        end

        def find_export
          @export = ::SearchExport::WorkbookExport.find(params[:id])
          head :not_found unless @export
        end

        def render_export(status: :ok)
          stored = @export.payload
          return head :not_found unless stored

          render json: { data: { id: @export.id, type: 'search_export_workbook', attributes: stored.slice('status', 'from', 'to', 'omitted_count', 'row_count', 'error') } }, status:
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
