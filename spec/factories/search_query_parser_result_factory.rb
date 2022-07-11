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
  end
end
