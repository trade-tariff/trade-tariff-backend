FactoryBot.define do
  factory :exempting_additional_code_override, class: 'GreenLanes::ExemptingAdditionalCodeOverride' do
    transient do
      reference_additional_code {}
    end

    additional_code { reference_additional_code.try(:additional_code) || Forgery(:basic).text(exactly: 3) }
    additional_code_type_id { reference_additional_code.try(:additional_code_type_id) || Forgery(:basic).text(exactly: 1) }
  end
end
