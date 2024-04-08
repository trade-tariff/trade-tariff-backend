# frozen_string_literal: true

module Api
  module V2
    module GreenLanes
      class GoodsNomenclaturePresenter < SimpleDelegator
        def initialize(goods_nomenclature, geographical_area_id = nil)
          super(goods_nomenclature)
          @geographical_area_id = geographical_area_id.presence
        end

        def parent_sid
          parent&.goods_nomenclature_sid
        end

        def applicable_category_assessment_ids
          @applicable_category_assessment_ids ||= applicable_category_assessments.map(&:id)
        end

        def applicable_category_assessments
          @applicable_category_assessments ||=
            ::GreenLanes::FindCategoryAssessmentsService.call \
              applicable_measures,
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

        def measure_ids
          @measure_ids ||= measures.map(&:measure_sid)
        end

        def measures
          @measures ||=
            MeasurePresenter.wrap(filter_measures_by_geographical_area(super))
        end

      private

        def filter_measures_by_geographical_area(unfiltered_measures)
          return unfiltered_measures if @geographical_area_id.blank?

          unfiltered_measures.select do |measure|
            measure.relevant_for_country? @geographical_area_id
          end
        end
      end
    end
  end
end
