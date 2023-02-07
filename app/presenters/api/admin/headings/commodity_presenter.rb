module Api
  module Admin
    module Headings
      class CommodityPresenter < SimpleDelegator
        attr_reader :search_references_count

        class << self
          def wrap(commodities, counts = {})
            commodities.map do |commodity|
              count = if counts.key?(commodity.goods_nomenclature_sid)
                        counts[commodity.goods_nomenclature_sid]
                      else
                        0
                      end

              new(commodity, count)
            end
          end
        end

        def initialize(commodity, search_references_count)
          @search_references_count = search_references_count

          super(commodity)
        end

        def to_admin_param
          "#{goods_nomenclature_item_id}-#{producline_suffix}"
        end
      end
    end
  end
end
