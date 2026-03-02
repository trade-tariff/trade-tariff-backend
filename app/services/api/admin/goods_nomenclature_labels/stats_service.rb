module Api
  module Admin
    module GoodsNomenclatureLabels
      class StatsService
        def call
          {
            total_goods_nomenclatures: total_goods_nomenclatures,
            descriptions_count: descriptions_count,
            known_brands_count: jsonb_array_sum('known_brands'),
            colloquial_terms_count: jsonb_array_sum('colloquial_terms'),
            synonyms_count: jsonb_array_sum('synonyms'),
            ai_created_only: ai_created_only,
            human_edited: human_edited,
            coverage_by_chapter: coverage_by_chapter,
          }
        end

        private

        def total_goods_nomenclatures
          base_dataset.count
        end

        def descriptions_count
          base_dataset.where(
            Sequel.lit("(labels->>'description') IS NOT NULL AND (labels->>'description') != ''"),
          ).count
        end

        def jsonb_array_sum(key)
          base_dataset
            .where(Sequel.lit("jsonb_typeof(labels->?) = 'array'", key))
            .sum(Sequel.lit('jsonb_array_length(labels->?)', key)) || 0
        end

        def ai_created_only
          base_dataset.where(manually_edited: false).count
        end

        def human_edited
          base_dataset.where(manually_edited: true).count
        end

        def coverage_by_chapter
          base_dataset
            .select_group(Sequel.lit('LEFT(goods_nomenclature_item_id, 2)').as(:chapter))
            .select_append(Sequel.function(:count, Sequel.lit('*')).as(:count))
            .order(Sequel.asc(:chapter))
            .all
            .map { |r| { chapter: r[:chapter], count: r[:count] } }
        end

        def base_dataset
          GoodsNomenclatureLabel.dataset
        end
      end
    end
  end
end
