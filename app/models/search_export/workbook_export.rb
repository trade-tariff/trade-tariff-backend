# frozen_string_literal: true

module SearchExport
  class WorkbookExport < Sequel::Model(:search_export_workbooks)
    plugin :timestamps, update_on_create: true

    QUEUED = 'queued'
    RUNNING = 'running'
    READY = 'ready'
    FAILED = 'failed'

    def pending?
      [QUEUED, RUNNING].include?(status)
    end

    def ready?
      status == READY && file.present?
    end
  end
end
