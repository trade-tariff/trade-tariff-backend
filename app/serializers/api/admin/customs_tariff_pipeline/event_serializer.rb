module Api
  module Admin
    module CustomsTariffPipeline
      class EventSerializer
        include JSONAPI::Serializer

        set_type :customs_tariff_pipeline_event

        attributes :event_type, :outcome, :customs_tariff_update_version,
                   :subject_type, :subject_id, :whodunnit, :occurred_at,
                   :duration_ms, :records_total, :records_succeeded,
                   :records_failed, :records_pending, :error_code,
                   :error_message, :metadata, :created_at
      end
    end
  end
end
