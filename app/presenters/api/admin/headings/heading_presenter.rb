module Api
  module Admin
    module Headings
      class HeadingPresenter < SimpleDelegator
        class << self
          def wrap(headings, search_reference_counts)
            headings.map do |heading|
              new(heading, search_reference_counts)
            end
          end
        end

        def initialize(heading, search_reference_counts)
          @search_reference_counts = search_reference_counts

          super(heading)
        end

        def chapter_id
          chapter.goods_nomenclature_sid
        end

        def commodities
          @commodities ||= CommodityPresenter.wrap(descendants, @search_reference_counts)
        end

        def commodity_ids
          commodities.map(&:to_admin_param)
        end

        def search_references_count
          @search_reference_counts[goods_nomenclature_sid]
        end
      end
    end
  end
end
