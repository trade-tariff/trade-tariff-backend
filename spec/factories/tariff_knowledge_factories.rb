FactoryBot.define do
  factory :tariff_knowledge_node, class: 'TariffKnowledge::Node' do
    node_type { TariffKnowledge::Node::GOODS_NOMENCLATURE }
    sequence(:key) { |n| "goods_nomenclature:#{goods_nomenclature_sid}:#{n}" }
    title { goods_nomenclature_item_id }
    metadata { Sequel.pg_jsonb_wrap({ 'source' => 'factory' }) }
    goods_nomenclature_sid { generate(:goods_nomenclature_sid) }
    goods_nomenclature_item_id { "0101#{generate(:commodity_short_code)}" }
    producline_suffix { GoodsNomenclature::NON_GROUPING_PRODUCTLINE_SUFFIX }
    goods_nomenclature_type { 'Commodity' }

    trait :note_fragment do
      node_type { TariffKnowledge::Node::NOTE_FRAGMENT }
      sequence(:key) { |n| "note_fragment:#{source_id}:#{n}" }
      title { 'Chapter 01 note fragment' }
      content { 'This chapter covers live animals.' }
      source_type { 'CustomsTariffChapterNote' }
      source_id { '01' }
      source_version { '1.31' }
      goods_nomenclature_sid { nil }
      goods_nomenclature_item_id { nil }
      producline_suffix { nil }
      goods_nomenclature_type { nil }
    end
  end

  factory :tariff_knowledge_edge, class: 'TariffKnowledge::Edge' do
    source_node { create(:tariff_knowledge_node, :note_fragment) }
    target_node { create(:tariff_knowledge_node) }
    relationship_type { TariffKnowledge::Edge::APPLIES_TO }
    metadata { Sequel.pg_jsonb_wrap({ 'source' => 'factory' }) }
  end

  factory :tariff_knowledge_compressed_note, class: 'TariffKnowledge::CompressedNote' do
    goods_nomenclature_sid { generate(:goods_nomenclature_sid) }
    goods_nomenclature_item_id { "0101#{generate(:commodity_short_code)}" }
    producline_suffix { GoodsNomenclature::NON_GROUPING_PRODUCTLINE_SUFFIX }
    goods_nomenclature_type { 'Commodity' }
    content { 'Use chapter and section notes when classifying this commodity.' }
    metadata { Sequel.pg_jsonb_wrap({ 'source_node_keys' => [] }) }
    context_hash { Digest::SHA256.hexdigest(content) }
    needs_review { false }
    approved { false }
    manually_edited { false }
    stale { false }
    expired { false }
    generated_at { Time.zone.now }
  end

  factory :tariff_knowledge_public_atar_ruling, class: 'TariffKnowledge::PublicAtarRuling' do
    sequence(:ref) { |n| "600000#{n.to_s.rjust(3, '0')}" }
    commodity_code { '9705100074' }
    goods_nomenclature_item_id { commodity_code.ljust(10, '0') }
    description { 'Venini, Cardin lights - Set of five.' }
    keywords { Sequel.pg_array(['CEILING LIGHTS', 'OF GLASS'], :text) }
    justification { 'Classification has been determined in accordance with GIR 1.' }
    validity_start_date { Date.new(2026, 6, 26) }
    validity_end_date { Date.new(2029, 6, 25) }
    source_url { "https://www.tax.service.gov.uk/search-for-advance-tariff-rulings/ruling/#{ref}" }
    raw_fields { Sequel.pg_jsonb_wrap({ 'Commodity code' => commodity_code }) }
    first_seen_at { Time.zone.parse('2026-06-26 09:00:00 UTC') }
    last_seen_at { first_seen_at }
    fetched_at { first_seen_at }
  end
end
