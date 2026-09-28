module Api
  module Admin
    class TariffKnowledgeSyntheticAtarsController < AdminController
      include Api::Admin::VersionBrowsing

      PERMITTED_ATTRIBUTES = %i[
        chapter
        real_user_search
        times_searched
        likely_heading
        description
        goods_nomenclature_item_id
        notes
        completed_by
      ].freeze

      def index
        render json: serialize(paginated_dataset.all, is_collection: true, meta: pagination_meta)
      end

      def show
        render json: serialize(synthetic_atar, serializer_options)
      end

      def create
        synthetic_atar = TariffKnowledge::SyntheticAtar.new(synthetic_atar_params)

        if synthetic_atar.save(raise_on_failure: false)
          render json: serialize(synthetic_atar.reload, serializer_options), status: :created
        else
          render json: serialize_errors(synthetic_atar), status: :unprocessable_content
        end
      end

      def update
        synthetic_atar.set(synthetic_atar_params)

        if synthetic_atar.save(raise_on_failure: false)
          render json: serialize(synthetic_atar.reload, serializer_options), status: :ok
        else
          render json: serialize_errors(synthetic_atar), status: :unprocessable_content
        end
      end

      def destroy
        synthetic_atar.destroy

        head :no_content
      end

      def versions
        versions = synthetic_atar.versions.all
        Version.preload_predecessors(versions)
        render json: Api::Admin::VersionSerializer.new(versions).serializable_hash
      end

    private

      def serializer_class
        Api::Admin::TariffKnowledgeSyntheticAtarSerializer
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
        TariffKnowledge::SyntheticAtar
          .search(params[:q])
          .for_chapter(params[:chapter])
          .order(Sequel.asc(:chapter), Sequel.asc(:real_user_search), Sequel.asc(:id))
      end

      def synthetic_atar
        @synthetic_atar ||= find_synthetic_atar
      end

      def find_synthetic_atar
        if filter_version_id.present? && !current_version?
          find_historical_synthetic_atar
        else
          TariffKnowledge::SyntheticAtar.where(id: params[:id].to_i).first || raise(Sequel::RecordNotFound)
        end
      end

      def find_historical_synthetic_atar
        version = versions_for_item.where(id: filter_version_id).first
        raise Sequel::RecordNotFound if version.blank?

        version.reify
      end

      def versions_for_item
        Version.where(item_type: 'TariffKnowledge::SyntheticAtar', item_id: params[:id].to_s)
      end

      def synthetic_atar_params
        params.require(:data).require(:attributes).permit(*PERMITTED_ATTRIBUTES).to_h.symbolize_keys
      end
    end
  end
end
