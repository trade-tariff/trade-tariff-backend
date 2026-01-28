module Api
  module Admin
    module GoodsNomenclatureLabels
      class StatsService
        def call
          {
            total_labels: total_labels,
            with_description: with_description,
            with_known_brands: with_known_brands,
            with_colloquial_terms: with_colloquial_terms,
            with_synonyms: with_synonyms,
            ai_created_only: ai_created_only,
            human_edited: human_edited,
          }
        end

        private

        def total_labels
          base_dataset.count
        end

        def with_description
          base_dataset.where(
            Sequel.lit("(labels->>'description') IS NOT NULL AND (labels->>'description') != ''"),
          ).count
        end

        def with_known_brands
          base_dataset.where(
            Sequel.lit("(labels->'known_brands')::text != '[]' AND (labels->'known_brands')::text != 'null' AND (labels->'known_brands') IS NOT NULL"),
          ).count
        end

        def with_colloquial_terms
          base_dataset.where(
            Sequel.lit("(labels->'colloquial_terms')::text != '[]' AND (labels->'colloquial_terms')::text != 'null' AND (labels->'colloquial_terms') IS NOT NULL"),
          ).count
        end

        def with_synonyms
          base_dataset.where(
            Sequel.lit("(labels->'synonyms')::text != '[]' AND (labels->'synonyms')::text != 'null' AND (labels->'synonyms') IS NOT NULL"),
          ).count
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
