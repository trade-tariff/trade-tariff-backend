module PublicUsers
  class DataExport < Sequel::Model(Sequel[:user_data_exports].qualify(:public))
    QUEUED = 'queued'.freeze
    PROCESSING = 'processing'.freeze
    COMPLETED = 'completed'.freeze
    FAILED = 'failed'.freeze

    CCWL = 'ccwl'.freeze

    EXPORTER_CLASSES = {
      CCWL => 'Api::User::ActiveCommoditiesService',
    }.freeze

    ALLOWED_STATUSES = [
      QUEUED,
      PROCESSING,
      COMPLETED,
      FAILED,
    ].freeze

    ALLOWED_EXPORT_TYPES = [CCWL].freeze

    plugin :auto_validations
    plugin :timestamps, update_on_create: true

    many_to_one :user, class: 'PublicUsers::User'

    def before_validation
      super
      self.exporter_class = EXPORTER_CLASSES[export_type]
    end

    def validate
      super
      errors.add(:status, 'is not valid') unless ALLOWED_STATUSES.include?(status)
      errors.add(:export_type, 'is not valid') unless ALLOWED_EXPORT_TYPES.include?(export_type)
    end

    dataset_module do
      def for_user(user_id)
        where(user_id: user_id)
      end
    end

    def exporter_klass
      exporter_class.constantize
    end
  end
end
