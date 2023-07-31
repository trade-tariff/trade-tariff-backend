class AdditionalCodeDescription < Sequel::Model
  include Formatter

  plugin :time_machine
  plugin :oplog, primary_key: %i[additional_code_description_period_sid additional_code_sid]

  set_primary_key %i[additional_code_description_period_sid additional_code_sid]

  custom_format :formatted_description, with: DescriptionFormatter, using: :description

  dataset_module do
    def with_fuzzy_description(description)
      where(Sequel.ilike(:description, "%#{description}%"))
    end
  end
end
