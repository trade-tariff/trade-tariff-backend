module TariffSynchronizer
  class TariffUpdateConformanceError < Sequel::Model
    many_to_one :base_update, key: :tariff_update_filename, class: BaseUpdate

    validates_presence_of :model_name, :model_primary_key

    plugin :serialization, :json, :model_primary_key,
           :model_values,
           :model_conformance_errors

    def model_primary_key
      # In some models primary key will be a single value and JSON deserialization
      # will fail. Return serialized primary key if deserialization fails
      super
    rescue JSON::ParserError
      values[:model_primary_key]
    end
  end
end
