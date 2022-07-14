FactoryBot.define do
  factory :search_result, class: 'Beta::Search::OpenSearchResult' do
    multiple_hits
    no_generate_statistics

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

    trait :no_generate_statistics do
      transient do
        generate_statistics { false }
      end
    end

    trait :generate_statistics do
      transient do
        generate_statistics { true }
      end
    end

    initialize_with do
      fixture_filename = Rails.root.join("spec/fixtures/beta/search/goods_nomenclatures/#{result_fixture}.json")
      search_result = JSON.parse(File.read(fixture_filename))
      presented_search_result = Hashie::TariffMash.new(search_result)

      search_result = Beta::Search::OpenSearchResult.build(presented_search_result, search_query_parser_result)

      search_result.generate_statistics if generate_statistics

      search_result
    end
  end
end
