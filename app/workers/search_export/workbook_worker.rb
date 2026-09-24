# frozen_string_literal: true

module SearchExport
  class WorkbookWorker
    include Sidekiq::Worker

    sidekiq_options queue: :default, retry: false

    def perform(export_id)
      export = WorkbookExport.with_pk!(export_id)
      export.update(status: WorkbookExport::RUNNING)
      result = Workbook.call(from: export.from_date, to: export.to_date)
      export.update(
        status: WorkbookExport::READY,
        file: Sequel::SQL::Blob.new(result.bytes),
        omitted_count: result.omitted_count,
        row_count: result.row_count,
        error_message: nil,
      )
    rescue Workbook::TooManyRows => e
      export&.update(status: WorkbookExport::FAILED, error_message: e.message)
    rescue StandardError
      export&.update(status: WorkbookExport::FAILED, error_message: 'The workbook could not be built.')
      raise
    end
  end
end
