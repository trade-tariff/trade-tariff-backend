class CertificateDescription < Sequel::Model
  include Formatter

  plugin :oplog, primary_key: [:certificate_description_period_sid]
  plugin :time_machine
  plugin :conformance_validator

  set_primary_key [:certificate_description_period_sid]

  format :formatted_description, with: DescriptionFormatter,
                                 using: :description

  def to_s
    description
  end
end
