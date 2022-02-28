module Api
  module Admin
    class TariffUpdateSerializer
      include JSONAPI::Serializer

      set_type :tariff_update

      set_id :filename

      attributes :update_type,
                 :state,
                 :issue_date,
                 :inserts,
                 :created_at,
                 :updated_at,
                 :filename,
                 :applied_at,
                 :filesize,
                 :exception_backtrace,
                 :issue_date,
                 :exception_queries,
                 :exception_class,
                 :file_presigned_url

      has_many :presence_errors, serializer: Api::Admin::PresenceErrorSerializer
    end
  end
end
