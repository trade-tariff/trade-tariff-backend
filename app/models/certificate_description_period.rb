class CertificateDescriptionPeriod < Sequel::Model
  plugin :oplog, primary_key: [:certificate_description_period_sid]
  plugin :time_machine

  set_primary_key [:certificate_description_period_sid]

  one_to_one :certificate_description, key: :certificate_description_period_sid,
                                       primary_key: :certificate_description_period_sid
end
