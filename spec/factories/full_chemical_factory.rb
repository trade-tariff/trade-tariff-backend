FactoryBot.define do
  factory :full_chemical do
    transient do
      goods_nomenclature { nil }
    end

    cus { '0154438-3' }
    cn_code { '0409000000-80' }
    cas_rn { '8028-66-8' }
    ec_number { '293-255-4' }
    un_number { nil }
    nomen { 'INCI' }
    name { 'mel powder' }
    goods_nomenclature_item_id { goods_nomenclature&.goods_nomenclature_item_id || '0409000000' }
    producline_suffix { goods_nomenclature&.producline_suffix || '80' }
    goods_nomenclature_sid { goods_nomenclature&.goods_nomenclature_sid || 123_456_789 }

    before(:create) do |full_chemical, evaluator|
      unless evaluator.goods_nomenclature
        goods_nomenclature_sid = create(
          :goods_nomenclature,
          goods_nomenclature_item_id: full_chemical.goods_nomenclature_item_id,
          producline_suffix: full_chemical.producline_suffix,
        ).goods_nomenclature_sid

        full_chemical.goods_nomenclature_sid = goods_nomenclature_sid
      end
    end
  end
end
