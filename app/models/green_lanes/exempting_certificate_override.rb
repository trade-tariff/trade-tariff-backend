module GreenLanes
  class ExemptingCertificateOverride < Sequel::Model(:green_lanes_exempting_certificate_overrides)
    plugin :timestamps, update_on_create: true
    plugin :auto_validations, not_null: :presence

    one_to_one :certificate, class: :Certificate,
                             key: %i[certificate_type_code certificate_code],
                             primary_key: %i[certificate_type_code certificate_code] do |ds|
      ds.with_actual(Certificate)
    end
  end
end
