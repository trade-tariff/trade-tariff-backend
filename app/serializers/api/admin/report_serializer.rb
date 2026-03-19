module Api
  module Admin
    class ReportSerializer
      include JSONAPI::Serializer

      set_type :report
      set_id :id

      attributes :name, :description, :missing_dependencies

      attribute :available, &:available_today?
      attribute :dependencies_missing, &:dependencies_missing?
      attribute :supports_email, &:supports_email?
      attribute :download_url do |report|
        report.available_today? ? report.download_link_today : nil
      end
    end
  end
end
