FactoryBot.define do
  factory :change, class: 'Change' do
    sequence(:goods_nomenclature_sid) { |n| n }

    goods_nomenclature_item_id { Array.new(10) { Random.rand(1..9) }.join }
    productline_suffix         { '80' }
    change_type                { 'commodity' }
    end_line                   { true }

    factory :change_measure do
      change_type { 'measure' }
    end
  end
end
