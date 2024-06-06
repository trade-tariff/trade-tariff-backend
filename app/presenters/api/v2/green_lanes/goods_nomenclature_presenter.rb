# frozen_string_literal: true

module Api
  module V2
    module GreenLanes
      class GoodsNomenclaturePresenter < ReferencedGoodsNomenclaturePresenter
        def applicable_category_assessment_ids
          @applicable_category_assessment_ids ||= applicable_category_assessments.map(&:id)
        end

        def applicable_category_assessments
          @applicable_category_assessments ||=
            ::GreenLanes::FindCategoryAssessmentsService.call \
              combined_applicable_measures,
              @geographical_area_id
        end

        def descendant_category_assessment_ids
          @descendant_category_assessment_ids ||= descendant_category_assessments.map(&:id)
        end

        def descendant_category_assessments
          @descendant_category_assessments ||=
            ::GreenLanes::FindCategoryAssessmentsService.call \
              combined_descendant_measures,
              @geographical_area_id
        end

        def ancestor_ids
          @ancestor_ids ||= ancestors.map(&:goods_nomenclature_sid)
        end

        def ancestors
          @ancestors ||=
            ReferencedGoodsNomenclaturePresenter.wrap(super, @geographical_area_id)
        end

        def descendant_ids
          @descendant_ids ||= descendants.map(&:goods_nomenclature_sid)
        end

        def descendants
          @descendants ||=
            ReferencedGoodsNomenclaturePresenter.wrap(super, @geographical_area_id)
        end

      private

        def combined_descendant_measures
          descendants.flat_map(&:measures) +
            descendants.flat_map(&:green_lanes_measures)
        end

        def combined_applicable_measures
          applicable_measures +
            green_lanes_measures +
            ancestors.flat_map(&:green_lanes_measures)
        end
      end
    end
  end
end
