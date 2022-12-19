module Api
  module Admin
    module Headings
      class CommodityPresenter < SimpleDelegator
        attr_reader :search_references_count

        class << self
          def wrap(commodities, counts = {})
            commodities.map do |commodity|
              count = counts.key?(commodity.twelvedigit) ? counts[commodity.twelvedigit] : 0

              new(commodity, count)
            end
          end
        end

        def initialize(commodity, search_references_count)
          @search_references_count = search_references_count

          super(commodity)
        end
      end
    end
  end
end
