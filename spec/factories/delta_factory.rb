FactoryBot.define do
  factory :delta, class: 'Delta' do
    sequence(:goods_nomenclature_sid) { |n| n }

    goods_nomenclature_item_id { 10.times.map { Random.rand(1..9) }.join }
    productline_suffix         { '80' }
    delta_type                 { 'commodity' }
    end_line                   { true }

    factory :delta_measure do
      delta_type { 'measure' }
    end
  end
end
