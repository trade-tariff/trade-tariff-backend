class CertificateDescription < Sequel::Model
  include Formatter

  plugin :oplog, primary_key: [:certificate_description_period_sid]
  plugin :time_machine

  set_primary_key [:certificate_description_period_sid]

  custom_format :formatted_description, with: DescriptionFormatter, using: :description

  def to_s
    description
  end

  dataset_module do
    def with_fuzzy_description(description)
      where(Sequel.ilike(:description, "%#{description}%"))
    end
  end
end
