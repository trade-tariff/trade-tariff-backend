module Api
  module Admin
    class VersionsController < AdminController
      def index
        render json: serialized_collection
      end

      RESTORABLE_TYPES = {
        'GoodsNomenclatureLabel' => GoodsNomenclatureLabel,
        'GoodsNomenclatureSelfText' => GoodsNomenclatureSelfText,
        'AdminConfiguration' => AdminConfiguration,
      }.freeze

      def restore
        version = Version.where(id: params[:id]).first
        raise Sequel::RecordNotFound unless version

        klass = RESTORABLE_TYPES[version.item_type]
        raise Sequel::RecordNotFound unless klass

        pk_col = Array(klass.primary_key).first
        record = klass.where(pk_col => version.item_id).first

        if record
          restorable = version.object.except(*non_restorable_keys(klass))
          record.set(restorable.transform_keys(&:to_sym))
        else
          skip = %w[id created_at updated_at]
          restorable = version.object.except(*skip)
          record = klass.new(restorable.transform_keys(&:to_sym))
        end

        record.save

        render json: VersionSerializer.new(
          record.versions.order(Sequel.desc(:id)).first,
        ).serializable_hash, status: :ok
      end

      private

      def non_restorable_keys(klass)
        pk_cols = Array(klass.primary_key).map(&:to_s)
        (pk_cols + %w[id created_at updated_at]).uniq
      end

      def serialized_collection
        versions = paginated_dataset.all
        Version.preload_predecessors(versions)

        VersionSerializer.new(
          versions,
          is_collection: true,
          meta: pagination_meta,
        ).serializable_hash
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
        dataset = Version.most_recent_first
        dataset = dataset.by_item_type(params[:item_type]) if params[:item_type].present?
        dataset = dataset.by_item_id(params[:item_id]) if params[:item_id].present?
        dataset = dataset.by_event(params[:event]) if params[:event].present?
        dataset = dataset.exclude(item_type: Array(params[:exclude_item_type])) if params[:exclude_item_type].present?
        dataset
      end
    end
  end
end
