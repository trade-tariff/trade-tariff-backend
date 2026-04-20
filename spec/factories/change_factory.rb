FactoryBot.define do
  factory :change, class: 'Change' do
    goods_nomenclature_sid     { generate(:goods_nomenclature_sid) }
    goods_nomenclature_item_id { Array.new(10) { Random.rand(1..9) }.join }
    productline_suffix         { GoodsNomenclature::NON_GROUPING_PRODUCTLINE_SUFFIX }
    change_type                { 'commodity' }
    end_line                   { true }

    factory :change_measure do
      change_type { 'measure' }
    end
  end
end
