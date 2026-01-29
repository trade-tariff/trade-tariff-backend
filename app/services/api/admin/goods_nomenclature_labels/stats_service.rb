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
          base_dataset.exclude(
            goods_nomenclature_sid: human_edited_sids_dataset,
          ).count
        end

        def human_edited
          base_dataset.where(
            goods_nomenclature_sid: human_edited_sids_dataset,
          ).count
        end

        def human_edited_sids_dataset
          GoodsNomenclatureLabel::Operation
            .where(operation: 'U')
            .select(:goods_nomenclature_sid)
            .distinct
        end

        def base_dataset
          TimeMachine.now { GoodsNomenclatureLabel.actual }
        end
      end
    end
  end
end
