module Api
  module Admin
    module GeneratedContentListing
      extend ActiveSupport::Concern

      def index
        render json: serialized_collection
      end

      private

      def serialized_collection
        serializer_class.new(
          paginated_dataset.all,
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
        dataset = model_class
          .admin_listing(include_expired: expired_listing?)
          .search(params[:q])
          .for_nomenclature_type(params[:type])
          .for_status(params[:status])
          .for_score_category(params[:score_category])

        dataset = dataset.exclude(listing_table[:approved] => true) if normal_review_listing?

        apply_sorting(dataset)
      end

      def normal_review_listing?
        params[:status].blank? && !search_query?
      end

      def expired_listing?
        params[:status] == 'expired'
      end

      def search_query?
        q = params[:q].to_s.strip

        q.match?(/\A\d{2,10}\z/) || q.length >= 2
      end

      def apply_sorting(dataset)
        dir = sort_direction == 'desc' ? :desc : :asc

        dataset.order(Sequel.public_send(dir, sort_column, nulls: :last))
      end

      def sort_column
        allowed = {
          'score' => Sequel.lit('score'),
          'goods_nomenclature_item_id' => listing_table[:goods_nomenclature_item_id],
        }

        allowed[params[:sort]] || Sequel.lit('score')
      end

      def sort_direction
        %w[asc desc].include?(params[:direction]) ? params[:direction] : 'asc'
      end

      def model_class
        raise NotImplementedError, "#{self.class} must define #model_class"
      end

      def serializer_class
        raise NotImplementedError, "#{self.class} must define #serializer_class"
      end

      def listing_table
        raise NotImplementedError, "#{self.class} must define #listing_table"
      end
    end
  end
end
