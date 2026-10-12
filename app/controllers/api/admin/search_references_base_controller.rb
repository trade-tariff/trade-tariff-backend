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
          usage: usage_param || SearchReference::SEARCH_USAGE,
          referenced: search_reference_resource_association_hash[:referenced],
        )

        if @search_reference.save
          enqueue_embedding_refresh
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
        previous_usage = @search_reference.usage
        @search_reference.set(title: sanitized_title)
        @search_reference.set(usage: usage_param) if usage_param

        if @search_reference.save
          remove_from_public_search(previous_usage)
          enqueue_embedding_refresh
          respond_with @search_reference
        else
          render json: Api::Admin::ErrorSerializationService.new(@search_reference).call,
                 status: :unprocessable_content
        end
      end

      def destroy
        @search_reference = search_reference_resource
        @search_reference.destroy
        enqueue_embedding_refresh

        respond_with @search_reference
      end

    private

      def search_references
        @search_references ||= search_reference_collection.for_usage(usage_filter).by_title.all
      end

      def search_reference_params
        params.require(:data).permit(:type, attributes: %i[title usage])
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

      def enqueue_embedding_refresh
        sid = @search_reference.goods_nomenclature_sid
        ScoreLabelBatchWorker.perform_async(sid) if sid
      end

      def sanitized_title
        return title unless title.to_s.start_with?('=', '+', '-', '@')

        "'#{title}"
      end

      def title
        @title ||= search_reference_params.dig(:attributes, :title)
      end

      def usage_param
        search_reference_params.dig(:attributes, :usage).presence
      end

      def usage_filter
        usage = params.dig(:filter, :usage)
        SearchReference::USAGE_FILTERS.include?(usage) ? usage : SearchReference::SEARCH_USAGE
      end

      def remove_from_public_search(previous_usage)
        ::SearchReferences::PublicSearchRemoval.call(@search_reference, previous_usage:)
      end
    end
  end
end
