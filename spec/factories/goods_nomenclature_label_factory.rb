FactoryBot.define do
  factory :goods_nomenclature_label do
    goods_nomenclature

    goods_nomenclature_sid do
      goods_nomenclature&.goods_nomenclature_sid || generate(:goods_nomenclature_sid)
    end

    labels { { description: 'Flibble' } }

    validity_start_date do
      goods_nomenclature&.validity_start_date || 2.years.ago.beginning_of_day
    end

    validity_end_date do
      goods_nomenclature&.validity_end_date
    end

    goods_nomenclature_item_id do
      goods_nomenclature&.goods_nomenclature_item_id || "0101#{generate(:commodity_short_code)}"
    end

    producline_suffix do
      goods_nomenclature&.producline_suffix || '80'
    end

    goods_nomenclature_type do
      goods_nomenclature&.class&.name || 'Commodity'
    end

    operation { 'C' }
    operation_date { Time.zone.now.utc }

    trait :with_labels do
      labels do
        {
          'descriptions' => ['Natural honey'],
          'colloquialisms' => ['bee honey'],
          'brands' => [],
          'synonyms' => [],
          'search_references' => [],
        }
      end
    end

    after(:create) do |_label, _evaluator|
      GoodsNomenclatureLabel.refresh!(concurrently: false) if Rails.env.test?
    end
  end
end
