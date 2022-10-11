FactoryBot.define do
  factory :search_query_parser_result, class: 'Beta::Search::SearchQueryParserResult' do
    adjectives { [] }
    nouns do
      %w[
        halibut
        sausage
        stenolepis
        cheese
        binocular
        parsnip
        pharmacy
        paper
      ]
    end
    verbs { [] }
    noun_chunks { ['halibut sausage stenolepis cheese binocular parsnip pharmacy paper'] }
    original_search_query { 'halbiut sausadge stenolepsis chese bnoculars parnsip farmacy pape' }
    corrected_search_query { 'halibut sausage stenolepis cheese binocular parsnip pharmacy paper' }

    trait :no_hits do
      original_search_query { 'flibble' }
      corrected_search_query { 'ribble' }

      adjectives { [] }
      noun_chunks { [] }
      nouns { [] }
      verbs { %w[ribble] }
    end

    trait :single_hit do
      original_search_query { 'ricotta' }
      corrected_search_query { 'ricotta' }

      adjectives { [] }
      noun_chunks { %w[ricotta] }
      nouns { %w[] }
      verbs { [] }
    end

    trait :multiple_hits do
      original_search_query { 'horses' }
      corrected_search_query { 'horses' }

      adjectives { [] }
      noun_chunks { %w[horses] }
      nouns { %w[horses] }
      verbs { [] }
    end

    trait :intercept_message do
      original_search_query { 'plasti' }
      corrected_search_query { 'plasti' }

      adjectives { [] }
      noun_chunks { %w[plasti] }
      nouns { %w[plasti] }
      verbs { [] }
    end

    trait :clothing do
      original_search_query { 'clothing' }
      corrected_search_query { 'clothing' }

      adjectives { [] }
      noun_chunks { %w[clothing] }
      nouns { %w[clothing] }
      verbs { [] }
    end

    trait :synonym do
      original_search_query { 'yakutian laika' }
      corrected_search_query { '' }

      adjectives { [] }
      noun_chunks { ['yakutian laika'] }
      nouns { %w[] }
      verbs { [] }
    end
  end
end
