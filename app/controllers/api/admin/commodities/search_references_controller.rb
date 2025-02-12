module Api
  module Admin
    module Commodities
      class SearchReferencesController < Api::Admin::SearchReferencesBaseController
        private

        def search_reference_collection
          commodity_or_subheading.search_references_dataset
        end

        def search_reference_resource_association_hash
          { referenced: commodity_or_subheading }
        end

        def collection_url
          [:admin, commodity.to_admin_param, @search_reference]
        end

        def commodity_or_subheading
          subheading.declarable? ? commodity : subheading
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

        def subheading
          @subheading ||= begin
            subheading = Subheading.actual
                   .by_code(commodity_id)
                   .by_productline_suffix(productline_suffix)
                   .take

            raise Sequel::RecordNotFound if subheading.goods_nomenclature_item_id.in?(HiddenGoodsNomenclature.codes)

            subheading
          end
        end

        def admin_commodity_id
          params[:admin_commodity_id].presence || params[:commodity_id]
        end

        def commodity_id
          admin_commodity_id.split('-', 2).first
        end

        def productline_suffix
          admin_commodity_id.split('-', 2)[1] || '80'
        end
      end
    end
  end
end
