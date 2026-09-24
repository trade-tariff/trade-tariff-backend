# frozen_string_literal: true

module SearchExport
  class WorkbookWorker
    include Sidekiq::Worker

    sidekiq_options queue: :default, retry: false

    def perform(export_id)
      export = WorkbookExport.select(*WorkbookExport::STATUS_COLUMNS).with_pk!(export_id)
      export.expire_if_stale!
      return unless export.status == WorkbookExport::QUEUED

      export.update(status: WorkbookExport::RUNNING)
      result = Workbook.call(from: export.from_date, to: export.to_date)
      export.expire_if_stale!
      WorkbookExport.where(id: export.id, status: WorkbookExport::RUNNING).update(
        status: WorkbookExport::READY,
        file: Sequel::SQL::Blob.new(result.bytes),
        omitted_count: result.omitted_count,
        row_count: result.row_count,
        error_message: nil,
        updated_at: Time.current,
      )
    rescue Workbook::TooManyRows => e
      export&.update(status: WorkbookExport::FAILED, error_message: e.message)
    rescue StandardError
      export&.update(status: WorkbookExport::FAILED, error_message: 'The workbook could not be built.')
      raise
    end
  end
end
