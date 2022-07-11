FactoryBot.define do
  factory :search_result, class: 'Beta::Search::SearchResult' do
    multiple_hits

    trait :no_hits do
      transient do
        result_fixture { 'no_hits' }
        search_query_parser_result { build(:search_query_parser_result, :no_hits) }
      end
    end

    trait :single_hit do
      transient do
        result_fixture { 'single_hit' }
        search_query_parser_result { build(:search_query_parser_result, :single_hit) }
      end
    end

    trait :multiple_hits do
      transient do
        result_fixture { 'multiple_hits' }
        search_query_parser_result { build(:search_query_parser_result, :multiple_hits) }
      end
    end

    initialize_with do
      fixture_filename = Rails.root.join("spec/fixtures/beta/search/goods_nomenclatures/#{result_fixture}.json")
      search_result = JSON.parse(File.read(fixture_filename))
      search_result = Hashie::TariffMash.new(search_result)

      Beta::Search::SearchResult.build(search_result, search_query_parser_result)
    end
  end
end
