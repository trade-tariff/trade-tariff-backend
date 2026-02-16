FactoryBot.define do
  factory :goods_nomenclature_self_text do
    transient do
      goods_nomenclature { nil }
    end

    goods_nomenclature_sid do
      goods_nomenclature&.goods_nomenclature_sid || generate(:goods_nomenclature_sid)
    end

    goods_nomenclature_item_id do
      goods_nomenclature&.goods_nomenclature_item_id || "0101#{generate(:commodity_short_code)}"
    end

    self_text { 'This commodity covers widgets used in manufacturing.' }
    generation_type { 'mechanical' }
    input_context { Sequel.pg_jsonb_wrap({ 'ancestors' => [], 'description' => 'Widgets' }) }
    context_hash { Digest::SHA256.hexdigest('default') }
    needs_review { false }
    manually_edited { false }
    stale { false }
    generated_at { Time.zone.now }

    trait :ai_generated do
      generation_type { 'ai' }
    end

    trait :stale do
      stale { true }
    end

    trait :needs_review do
      needs_review { true }
    end

    trait :manually_edited do
      manually_edited { true }
    end
  end
end
