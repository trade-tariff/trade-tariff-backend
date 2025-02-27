FactoryBot.define do
  sequence(:export_refund_nomenclature_sid) { |n| n }

  factory :export_refund_nomenclature do
    transient do
      indents { 1 }
    end

    export_refund_nomenclature_sid { generate(:export_refund_nomenclature_sid) }
    goods_nomenclature_item_id { Array.new(10) { Random.rand(9) }.join }
    export_refund_code   { Array.new(3) { Random.rand(9) }.join }
    additional_code_type { Random.rand(9) }
    productline_suffix   { [10, 20, 80].sample }
    validity_start_date  { 2.years.ago.beginning_of_day }
    validity_end_date    { nil }

    trait :with_indent do
      after(:create) do |gono, evaluator|
        create(:export_refund_nomenclature_indent, export_refund_nomenclature_sid: gono.export_refund_nomenclature_sid,
                                                   number_export_refund_nomenclature_indents: evaluator.indents)
      end
    end
  end

  factory :export_refund_nomenclature_indent do
    export_refund_nomenclature_sid { generate(:export_refund_nomenclature_sid) }
    export_refund_nomenclature_indents_sid { generate(:export_refund_nomenclature_sid) }
    number_export_refund_nomenclature_indents { Forgery(:basic).number }
    validity_start_date { 3.years.ago.beginning_of_day }
    validity_end_date   { nil }
  end

  factory :export_refund_nomenclature_description_period do
    export_refund_nomenclature_sid { generate(:sid) }
    export_refund_nomenclature_description_period_sid { generate(:sid) }
    validity_start_date { 3.years.ago.beginning_of_day }
    validity_end_date   { nil }
  end

  factory :export_refund_nomenclature_description do
    transient do
      validity_start_date { 3.years.ago.beginning_of_day }
      validity_end_date { nil }
      valid_at { Time.zone.now.ago(2.years) }
      valid_to { nil }
    end

    export_refund_nomenclature_sid { generate(:sid) }
    description { Forgery(:basic).text }
    export_refund_nomenclature_description_period_sid { generate(:sid) }

    after(:create) do |gono_description, evaluator|
      create(:export_refund_nomenclature_description_period, export_refund_nomenclature_description_period_sid: gono_description.export_refund_nomenclature_description_period_sid,
                                                             export_refund_nomenclature_sid: gono_description.export_refund_nomenclature_sid,
                                                             goods_nomenclature_item_id: gono_description.goods_nomenclature_item_id,
                                                             validity_start_date: evaluator.valid_at,
                                                             validity_end_date: evaluator.valid_to)
    end
  end
end
