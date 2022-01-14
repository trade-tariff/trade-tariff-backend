# NOTE: for shared base behaviour inherited by
#
# * api/admin/search_references_controller
# * api/admin/sections/search_references_controller
# * api/admin/chapters/search_references_controller
# * api/admin/headings/search_references_controller

module Api
  module Admin
    class SearchReferencesBaseController < ApiController
      before_action :authenticate_user!

      after_action :set_pagination_headers, only: [:index]

      def index
        search_references = search_reference_collection.by_title.paginate(page, per_page).all

        render json: Api::Admin::SearchReferences::SearchReferenceListSerializer.new(search_references).serializable_hash
      end

      def show
        @search_reference = search_reference_resource
        options = { is_collection: false }
        options[:include] = [:referenced, 'referenced.chapter', 'referenced.chapter.guides', 'referenced.section']

        render json: Api::Admin::SearchReferences::SearchReferenceSerializer.new(@search_reference, options).serializable_hash
      end

      def create
        @search_reference = SearchReference.new(
          search_reference_params[:attributes].merge(search_reference_resource_association_hash)
        )

        if @search_reference.save
          options = { is_collection: false }
          options[:include] = [:referenced, 'referenced.chapter', 'referenced.chapter.guides', 'referenced.section']
          render json: Api::Admin::SearchReferences::SearchReferenceSerializer.new(@search_reference, options).serializable_hash, status: :created
        else
          data = { errors: [] }
          data[:errors] = @search_reference.errors.full_messages.map do |error|
            { title: error }
          end
          render json: data, status: :unprocessable_entity
        end
      end

      def update
        @search_reference = search_reference_resource
        @search_reference.set(
          search_reference_params[:attributes]
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
        params.require(:data).permit(:type, attributes: [:title])
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
