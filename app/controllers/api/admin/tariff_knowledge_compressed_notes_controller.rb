module Api
  module Admin
    class TariffKnowledgeCompressedNotesController < AdminController
      def index
        render json: serializer_class.new(
          paginated_dataset.all,
          is_collection: true,
          meta: pagination_meta,
        ).serializable_hash
      end

    private

      def paginated_dataset
        @paginated_dataset ||= filtered_dataset.paginate(current_page, per_page)
      end

      def filtered_dataset
        dataset = TariffKnowledge::CompressedNote.dataset
        dataset = apply_status_filter(dataset)
        dataset = apply_search(dataset)

        dataset.order(Sequel.asc(:goods_nomenclature_item_id))
      end

      def apply_status_filter(dataset)
        case params[:status]
        when 'expired'
          dataset.where(expired: true)
        when 'approved'
          dataset.where(approved: true, expired: false)
        when 'stale'
          dataset.where(stale: true, expired: false)
        when 'manually_edited'
          dataset.where(manually_edited: true, expired: false)
        when 'needs_review'
          dataset.where(needs_review: true, expired: false)
        else
          dataset.where(approved: false, expired: false)
        end
      end

      def apply_search(dataset)
        query = params[:q].to_s.strip
        return dataset if query.blank?

        if query.match?(/\A\d{2,10}\z/)
          dataset.where(Sequel.like(:goods_nomenclature_item_id, "#{query}%"))
        elsif query.length >= 2
          dataset.where(Sequel.ilike(:content, "%#{query}%"))
        else
          dataset
        end
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

      def serializer_class
        Api::Admin::TariffKnowledgeCompressedNoteSerializer
      end
    end
  end
end
