FactoryBot.define do
  factory :goods_nomenclature_label do
    goods_nomenclature { build(:commodity) }

    goods_nomenclature_sid do
      goods_nomenclature&.goods_nomenclature_sid || generate(:goods_nomenclature_sid)
    end

    labels { { 'description' => 'Flibble' } }
    description { 'Flibble' }
    synonyms { Sequel.pg_array([], :text) }
    colloquial_terms { Sequel.pg_array([], :text) }
    known_brands { Sequel.pg_array([], :text) }

    goods_nomenclature_item_id do
      goods_nomenclature&.goods_nomenclature_item_id || "0101#{generate(:commodity_short_code)}"
    end

    producline_suffix do
      goods_nomenclature&.producline_suffix || '80'
    end

    goods_nomenclature_type do
      goods_nomenclature&.class&.name || 'Commodity'
    end

    stale { false }
    manually_edited { false }
    context_hash { nil }

    trait :with_labels do
      labels do
        {
          'description' => 'Natural honey',
          'colloquial_terms' => ['bee honey'],
          'known_brands' => [],
          'synonyms' => [],
        }
      end
      description { 'Natural honey' }
      colloquial_terms { Sequel.pg_array(['bee honey'], :text) }
      known_brands { Sequel.pg_array([], :text) }
      synonyms { Sequel.pg_array([], :text) }
    end

    trait :stale do
      stale { true }
    end

    trait :manually_edited do
      manually_edited { true }
    end
  end
end
