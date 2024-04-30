FactoryBot.define do
  factory :exempting_certificate_override, class: 'GreenLanes::ExemptingCertificateOverride' do
    transient do
      certificate {}
    end

    certificate_code { certificate.try(:certificate_code) || Forgery(:basic).text(exactly: 3) }
    certificate_type_code { certificate.try(:certificate_type_code) || Forgery(:basic).text(exactly: 1) }
  end
end
