module Api
  module Admin
    class VersionsController < AdminController
      def index
        render json: serialized_collection
      end

      def show
        version = Version.where(id: params[:id]).first
        raise Sequel::RecordNotFound unless version

        render json: VersionSerializer.new(version).serializable_hash, status: :ok
      end

      RESTORABLE_TYPES = {
        'GoodsNomenclatureLabel' => GoodsNomenclatureLabel,
        'GoodsNomenclatureSelfText' => GoodsNomenclatureSelfText,
        'AdminConfiguration' => AdminConfiguration,
        'DescriptionIntercept' => DescriptionIntercept,
        'TariffKnowledge::SyntheticAtar' => TariffKnowledge::SyntheticAtar,
        'GoodsNomenclatureIntercept' => GoodsNomenclatureIntercept,
        'CustomsTariffSectionNote' => CustomsTariffSectionNote,
        'CustomsTariffChapterNote' => CustomsTariffChapterNote,
        'SearchReference' => SearchReference,
      }.freeze

      # Restoring a deleted record normally gives it a new primary key. These
      # types keep their original key so their version history stays continuous.
      PRESERVE_ID_ON_RECREATE = %w[SearchReference].freeze

      SEARCH_REFERENCE_BLOCKED_REASONS = {
        missing: 'no longer exists',
        expired: 'has expired',
        superseded: 'has been superseded',
        unknown: 'is no longer current',
      }.freeze

      def restore
        version = Version.where(id: params[:id]).first
        raise Sequel::RecordNotFound unless version

        klass = RESTORABLE_TYPES[version.item_type]
        raise Sequel::RecordNotFound unless klass

        pk_col = Array(klass.primary_key).first
        record = klass.where(pk_col => version.item_id).first

        previous_usage = record.usage if record.is_a?(SearchReference)

        if record
          restorable = version.object.except(*non_restorable_keys(klass))
          record.set(restorable.transform_keys(&:to_sym))
        else
          record = recreate_record(klass, version)
        end

        blocked_reason = restore_blocked_reason(record)
        return render_restore_error(blocked_reason) if blocked_reason

        return render_restore_error(record.errors.full_messages.to_sentence) unless record.save

        after_restore(record, previous_usage:)

        render json: VersionSerializer.new(
          record.versions.order(Sequel.desc(:id)).first,
        ).serializable_hash, status: :ok
      end

    private

      def recreate_record(klass, version)
        restorable = version.object.except('id', 'created_at', 'updated_at')
        record = klass.new(restorable.transform_keys(&:to_sym))
        record.values[:id] = version.object['id'] if PRESERVE_ID_ON_RECREATE.include?(version.item_type)
        record
      end

      def restore_blocked_reason(record)
        return unless record.is_a?(SearchReference)

        result = TimeMachine.no_time_machine { ::SearchReferences::InvalidationReasonService.call(record) }
        return unless result[:removal_alert_required]

        explanation = SEARCH_REFERENCE_BLOCKED_REASONS.fetch(result[:reason], 'is no longer current')
        message = "Cannot restore this search reference because commodity #{result[:goods_nomenclature_item_id]} #{explanation}"
        message += " (successors: #{result[:successor_ids].join(', ')})" if result[:successor_ids].present?
        "#{message}."
      end

      def after_restore(record, previous_usage:)
        return unless record.is_a?(SearchReference)

        ::SearchReferences::PublicSearchRemoval.call(record, previous_usage:)

        sid = record.goods_nomenclature_sid
        ScoreLabelBatchWorker.perform_async(sid) if sid
      end

      def render_restore_error(detail)
        render json: { errors: [{ status: '422', title: 'Restore failed', detail: }] },
               status: :unprocessable_content
      end

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
