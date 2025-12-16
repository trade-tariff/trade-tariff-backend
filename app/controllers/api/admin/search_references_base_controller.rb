# NOTE: for shared base behaviour inherited by
#
# * api/admin/search_references_controller
# * api/admin/sections/search_references_controller
# * api/admin/chapters/search_references_controller
# * api/admin/headings/search_references_controller

module Api
  module Admin
    class SearchReferencesBaseController < AdminController
      def index
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
          title: sanitized_title,
          referenced: search_reference_resource_association_hash[:referenced],
        )

        if @search_reference.save
          options = { is_collection: false }
          options[:include] = [:referenced, 'referenced.chapter', 'referenced.chapter.guides', 'referenced.section']
          render json: Api::Admin::SearchReferences::SearchReferenceSerializer.new(@search_reference, options).serializable_hash, status: :created
        else
          render json: Api::Admin::ErrorSerializationService.new(@search_reference).call,
                 status: :unprocessable_content
        end
      end

      def update
        @search_reference = search_reference_resource
        @search_reference.set(title: sanitized_title)

        if @search_reference.save
          respond_with @search_reference
        else
          render json: Api::Admin::ErrorSerializationService.new(@search_reference).call,
                 status: :unprocessable_content
        end
      end

      def destroy
        @search_reference = search_reference_resource
        @search_reference.destroy

        respond_with @search_reference
      end

      private

      def search_references
        @search_references ||= search_reference_collection.by_title.all
      end

      def search_reference_params
        params.require(:data).permit(:type, attributes: [:title])
      end

      def search_reference_collection
        raise ArgumentError, '#search_reference_collection should be overriden by inheriting classes'
      end

      def search_reference_resource
        search_reference_collection.with_pk!(params[:id])
      end

      def search_reference_resource_association_hash
        raise ArgumentError, '#search_reference_resource_association_hash should be overriden by inheriting classes'
      end

      def set_pagination_headers
        headers['X-Meta'] = {
          pagination: {
            total: search_reference_collection.count,
            offset: page * per_page,
            page:,
            per_page:,
          },
        }.to_json
      end

      def sanitized_title
        return title unless title.to_s.start_with?('=', '+', '-', '@')

        "'#{title}"
      end

      def title
        @title ||= search_reference_params.dig(:attributes, :title)
      end
    end
  end
end
