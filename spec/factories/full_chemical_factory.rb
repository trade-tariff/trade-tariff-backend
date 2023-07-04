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
    goods_nomenclature_item_id do
      (goods_nomenclature && goods_nomenclature.goods_nomenclature_item_id) || '0409000000'
    end
    producline_suffix do
      (goods_nomenclature && goods_nomenclature&.producline_suffix) || '80'
    end
    goods_nomenclature_sid do
      (goods_nomenclature && goods_nomenclature&.goods_nomenclature_sid) || generate(:goods_nomenclature_sid)
    end

    before(:create) do |full_chemical, evaluator|
      if evaluator.goods_nomenclature.nil?
        if full_chemical.goods_nomenclature_sid
          create(
            :goods_nomenclature,
            goods_nomenclature_sid: full_chemical.goods_nomenclature_sid,
            goods_nomenclature_item_id: full_chemical.goods_nomenclature_item_id,
            producline_suffix: full_chemical.producline_suffix,
          )
        else
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
end
