FactoryBot.define do
  factory :goods_nomenclature_query, class: 'Beta::Search::GoodsNomenclatureQuery' do
    original_search_query {}
    adjectives { [] }
    noun_chunks { [] }
    nouns { [] }
    verbs { [] }
    filters { {} }
    quoted { [] }

    trait :quoted do
      quoted { ["'cherry tomatoes'"] }
    end

    trait :full_query do
      adjectives { %w[tall] }
      noun_chunks { ['tall running man'] }
      nouns { %w[man] }
      verbs { %w[run] }
    end

    trait :nouns do
      noun_chunks { %w[ricotta] }
      nouns { %w[ricotta] }
    end

    trait :adjectives do
      adjectives { %w[ricotta] }
    end

    trait :verbs do
      verbs { %w[ricotta] }
    end

    trait :single_hit do
      noun_chunks { %w[ricotta] }
      nouns { %w[ricotta] }
    end

    trait :numeric do
      original_search_query { '0101' }
      numeric { true }
    end

    trait :filter do
      single_hit
      filters { { 'cheese_type' => 'fresh' } }
    end

    trait :untokenised do
      original_search_query { 'qwdwefwfwWWWWWWWWRGRGEWGEWGEWGEWG' }
      adjectives { [] }
      noun_chunks { [] }
      nouns { [] }
      verbs { [] }
      filters { {} }
      quoted { [] }
    end
  end
end
