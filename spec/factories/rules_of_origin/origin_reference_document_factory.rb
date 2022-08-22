FactoryBot.define do
  factory :rules_of_origin_origin_reference_document, class: 'RulesOfOrigin::OriginReferenceDocument' do
    ord_title { 'Some title' }
    ord_version { '1.1' }
    ord_date { '28 December 2021' }
    ord_original { '211203_ORD_Japan_V1.1.odt' }
  end
end
