# NOTE: for shared base behaviour inherited by
#
# * api/v1/search_references_controller
# * api/v1/sections/search_references_controller
# * api/v1/chapters/search_references_controller
# * api/v1/headings/search_references_controller

module Api
  module V1
    class SearchReferencesBaseController < ApiController
      before_action :authenticate_user!

      after_action :set_pagination_headers, only: [:index]

      def index
        @search_references = begin
          search_reference_collection.by_title
                                 .paginate(page, per_page)
        rescue Sequel::Error
         search_reference_collection.by_title
                                .paginate(page, per_page)
        end
      end

      def show
        @search_reference = search_reference_resource
      end

      def create
        @search_reference = SearchReference.new(
          search_reference_params.merge(search_reference_resource_association_hash)
        )

        @search_reference.save

        respond_with @search_reference, location: collection_url
      end

      def update
        @search_reference = search_reference_resource
        @search_reference.set(
          search_reference_params
        )
        @search_reference.save

        respond_with @search_reference
      end

      def destroy
        @search_reference = search_reference_resource
        @search_reference.destroy

        respond_with @search_reference
      end

      private

      def per_page
        params.fetch(:per_page, default_limit).to_i
      end

      def page
        params.fetch(:page, default_page).to_i
      end

      def default_page
        1
      end

      def default_limit
        25
      end

      def search_reference_params
        params.require(:search_reference).slice(:title).permit(:title)
      end

      def search_reference_collection
        raise ArgumentError.new('#search_reference_collection should be overriden by inheriting classes')
      end

      def search_reference_resource
        search_reference_collection.with_pk!(params[:id])
      end

      def search_reference_resource_association_hash
        raise ArgumentError.new('#search_reference_resource_association_hash should be overriden by inheriting classes')
      end

      def set_pagination_headers
        headers['X-Meta'] = {
          pagination: {
            total: search_reference_collection.count,
            offset: page * per_page,
            page: page,
            per_page: per_page
          }
        }.to_json
      end
    end
  end
end
