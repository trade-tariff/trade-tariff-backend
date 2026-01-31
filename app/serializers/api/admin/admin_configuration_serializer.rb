module Api
  module Admin
    class AdminConfigurationSerializer
      include JSONAPI::Serializer

      set_type :admin_configuration
      set_id :name

      attributes :name, :value, :config_type, :area, :description
    end
  end
end
