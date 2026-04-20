module Api
  module Admin
    class DescriptionInterceptsController < AdminController
      include Api::Admin::VersionBrowsing

      def index
        render json: serialize(paginated_dataset.all, is_collection: true, meta: pagination_meta)
      end

      def show
        render json: serialize(description_intercept, serializer_options)
      end

      def create
        description_intercept = DescriptionIntercept.new(description_intercept_params)

        if description_intercept.save(raise_on_failure: false)
          render json: serialize(description_intercept.reload, serializer_options), status: :created
        else
          render json: serialize_errors(description_intercept), status: :unprocessable_content
        end
      end

      def update
        description_intercept.set(description_intercept_params)

        if description_intercept.save(raise_on_failure: false)
          render json: serialize(description_intercept.reload, serializer_options), status: :ok
        else
          render json: serialize_errors(description_intercept), status: :unprocessable_content
        end
      end

      def versions
        versions = description_intercept.versions.all
        Version.preload_predecessors(versions)
        render json: Api::Admin::VersionSerializer.new(versions).serializable_hash
      end

      private

      def serializer_class
        Api::Admin::DescriptionInterceptSerializer
      end

      def pagination_meta
        {
          pagination: {
            page: current_page,
            per_page:,
            total_count: paginated_dataset.pagination_record_count,
          },
        }
      end

      def paginated_dataset
        @paginated_dataset ||= filtered_dataset.paginate(current_page, per_page)
      end

      def filtered_dataset
        DescriptionIntercept
          .search(params[:q])
          .for_source(params[:source])
          .with_filtering(params[:filtering])
          .with_escalation(params[:escalates])
          .with_guidance(params[:guidance])
          .with_excluded(params[:excluded])
          .order(Sequel.asc(:term), Sequel.asc(:id))
      end

      def description_intercept
        @description_intercept ||= find_description_intercept
      end

      def find_description_intercept
        if filter_version_id.present? && !current_version?
          find_historical_description_intercept
        else
          find_current_description_intercept
        end
      end

      def find_current_description_intercept
        DescriptionIntercept.where(id: params[:id].to_i).first || raise(Sequel::RecordNotFound)
      end

      def find_historical_description_intercept
        version = versions_for_item.where(id: filter_version_id).first
        raise Sequel::RecordNotFound if version.blank?

        version.reify
      end

      def versions_for_item
        Version.where(item_type: 'DescriptionIntercept', item_id: params[:id].to_s)
      end

      def description_intercept_params
        attrs = params.require(:data).require(:attributes)
        permitted = attrs.permit(
          :term,
          :message,
          :excluded,
          :guidance_level,
          :guidance_location,
          :escalate_to_webchat,
          sources: [],
          filter_prefixes: [],
        )

        {}.tap do |result|
          result[:term] = permitted[:term] if permitted.key?(:term)
          result[:message] = permitted[:message] if permitted.key?(:message)
          result[:excluded] = permitted[:excluded] if permitted.key?(:excluded)
          result[:guidance_level] = permitted[:guidance_level] if permitted.key?(:guidance_level)
          result[:guidance_location] = permitted[:guidance_location] if permitted.key?(:guidance_location)
          result[:escalate_to_webchat] = permitted[:escalate_to_webchat] if permitted.key?(:escalate_to_webchat)
          result[:sources] = Sequel.pg_array(Array(permitted[:sources]).compact_blank, :text) if permitted.key?(:sources)
          result[:filter_prefixes] = Sequel.pg_array(Array(permitted[:filter_prefixes]).compact_blank, :text) if permitted.key?(:filter_prefixes)
        end
      end
    end
  end
end
