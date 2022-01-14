module Api
  module Admin
    module Commodities
      class SearchReferencesController < Api::Admin::SearchReferencesBaseController
        private

        def search_reference_collection
          commodity.search_references_dataset
        end

        def search_reference_resource_association_hash
          { commodity: commodity }
        end

        def collection_url
          [:admin, commodity.admin_id, @search_reference]
        end

        def commodity
          @commodity ||= begin
            commodity = Commodity.actual
                   .by_code(commodity_id)
                   .by_productline_suffix(productline_suffix)
                   .take

            raise Sequel::RecordNotFound if commodity.goods_nomenclature_item_id.in?(HiddenGoodsNomenclature.codes)

            commodity
          end
        end

        def commodity_id
          params[:commodity_id].split('-', 2).first
        end

        def productline_suffix
          params[:commodity_id].split('-', 2)[1] || '80'
        end
      end
    end
  end
end
