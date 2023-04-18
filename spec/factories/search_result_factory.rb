FactoryBot.define do
  factory :search_result, class: 'Beta::Search::OpenSearchResult' do
    transient do
      goods_nomenclature_item_id {}
    end

    multiple_hits
    no_generate_heading_and_chapter_statistics
    no_generate_guide_statistics
    no_generate_facet_statistics

    goods_nomenclature_query {}
    search_reference {}

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

    trait :clothing do
      transient do
        result_fixture { 'clothing' }
        search_query_parser_result { build(:search_query_parser_result, :clothing) }
      end
    end

    trait :multiple_hits do
      transient do
        result_fixture { 'multiple_hits' }
        search_query_parser_result { build(:search_query_parser_result, :multiple_hits) }
      end
    end

    trait :intercept_message do
      transient do
        result_fixture { 'multiple_hits' }
        search_query_parser_result { build(:search_query_parser_result, :intercept_message) }
      end
    end

    trait :no_guides do
      multiple_hits
    end

    trait :no_generate_heading_and_chapter_statistics do
      transient do
        generate_heading_and_chapter_statistics { false }
      end
    end

    trait :generate_heading_and_chapter_statistics do
      transient do
        generate_heading_and_chapter_statistics { true }
      end
    end

    trait :no_generate_guide_statistics do
      transient do
        generate_guide_statistics { false }
      end
    end

    trait :generate_guide_statistics do
      transient do
        generate_guide_statistics { true }
      end
    end

    trait :heading do
      transient do
        goods_nomenclature_item_id { '0101' }
      end
    end

    trait :chapter do
      transient do
        goods_nomenclature_item_id { '01' }
      end
    end

    trait :commodity do
      transient do
        goods_nomenclature_item_id { '0101210000' }
      end
    end

    trait :partial_goods_nomenclature do
      transient do
        goods_nomenclature_item_id { '010110' }
      end
    end

    trait :with_goods_nomenclature do
      goods_nomenclature_query {}
      goods_nomenclature { create(:commodity) }
    end

    trait :without_search_reference do
      goods_nomenclature_query do
        build(
          :goods_nomenclature_query,
          :numeric,
          original_search_query: goods_nomenclature_item_id || '0101',
        )
      end
      search_reference {}
    end

    trait :no_generate_facet_statistics do
      transient do
        generate_facet_statistics { false }
      end
    end

    trait :generate_facet_statistics do
      transient do
        generate_facet_statistics { true }
      end
    end

    trait :with_numeric_search_query do
      goods_nomenclature_query do
        build(
          :goods_nomenclature_query,
          :numeric,
          original_search_query: goods_nomenclature_item_id || '0101',
        )
      end
    end

    initialize_with do
      fixture_filename = Rails.root.join("spec/fixtures/beta/search/goods_nomenclatures/#{result_fixture}.json")
      search_result = JSON.parse(File.read(fixture_filename))
      presented_search_result = Hashie::TariffMash.new(search_result)

      search_result = Beta::Search::OpenSearchResult::WithHits.build(
        presented_search_result,
        search_query_parser_result,
        goods_nomenclature_query || build(:goods_nomenclature_query),
        search_reference,
      )

      search_result.generate_heading_and_chapter_statistics if generate_heading_and_chapter_statistics
      search_result.generate_guide_statistics if generate_guide_statistics
      search_result.generate_facet_statistics if generate_facet_statistics

      search_result
    end
  end
end
