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

        def commodities
          @commodities ||= CommodityPresenter.wrap(super, @search_reference_counts)
        end

        def search_references_count
          @search_reference_counts[twelvedigit]
        end
      end
    end
  end
end
