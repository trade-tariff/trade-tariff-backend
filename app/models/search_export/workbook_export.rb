# frozen_string_literal: true

module SearchExport
  class WorkbookExport < Sequel::Model(:search_export_workbooks)
    plugin :timestamps, update_on_create: true

    QUEUED = 'queued'
    RUNNING = 'running'
    READY = 'ready'
    FAILED = 'failed'
    DEADLINE = 15.minutes
    STATUS_COLUMNS = %i[id status from_date to_date omitted_count row_count error_message created_at updated_at].freeze

    def expire_if_stale!
      return unless pending? && updated_at < DEADLINE.ago

      self.class.where(id:, status: [QUEUED, RUNNING]).where { updated_at < DEADLINE.ago }
          .update(status: FAILED, error_message: 'The workbook timed out. Please request it again.', updated_at: Time.current)
      values.merge!(self.class.select(*STATUS_COLUMNS).with_pk!(id).values)
    end

    def pending?
      [QUEUED, RUNNING].include?(status)
    end

    def ready?
      status == READY && file.present?
    end
  end
end
