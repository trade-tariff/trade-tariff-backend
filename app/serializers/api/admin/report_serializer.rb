module Api
  module Admin
    class ReportSerializer
      include JSONAPI::Serializer

      set_type :report
      set_id :id

      attributes :name, :description, :missing_dependencies

      attribute :available, &:available_today?
      attribute :dependencies_missing, &:dependencies_missing?
    end
  end
end
