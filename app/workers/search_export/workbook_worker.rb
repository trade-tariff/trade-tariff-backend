# frozen_string_literal: true

module SearchExport
  class WorkbookWorker
    include Sidekiq::Worker

    sidekiq_options queue: :default, retry: false

    def perform(export_id)
      export = WorkbookExport.find(export_id)
      return unless export&.claim

      payload = export.payload
      return unless payload

      result = Workbook.call(from: Date.iso8601(payload.fetch('from')), to: Date.iso8601(payload.fetch('to')))
      export.finish(result)
    rescue CloudwatchReader::Error => e
      export&.fail(e.message)
    rescue StandardError
      export&.fail('The workbook could not be built.')
      raise
    end
  end
end
