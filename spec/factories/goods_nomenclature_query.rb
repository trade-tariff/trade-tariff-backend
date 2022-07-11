FactoryBot.define do
  factory :goods_nomenclature_query, class: 'Beta::Search::GoodsNomenclatureQuery' do
    adjectives {}
    noun_chunks {}
    nouns {}
    verbs {}

    trait :full_query do
      adjectives { %w[tall] }
      noun_chunks { ['tall running man'] }
      nouns { %w[man] }
      verbs { %w[run] }
    end
  end
end
