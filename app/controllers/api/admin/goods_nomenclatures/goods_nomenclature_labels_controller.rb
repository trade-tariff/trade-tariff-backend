module Api
  module Admin
    module GoodsNomenclatures
      class GoodsNomenclatureLabelsController < AdminController
        include Api::Admin::VersionBrowsing

        def show
          render json: serialize(goods_nomenclature_label, serializer_options)
        end

        def update
          goods_nomenclature_label.set(label_params.merge(manually_edited: true))

          if goods_nomenclature_label.save(raise_on_failure: false)
            reindex_goods_nomenclature
            ScoreLabelBatchWorker.perform_async(goods_nomenclature_label.goods_nomenclature_sid)
            render json: serialize(goods_nomenclature_label.reload, serializer_options), status: :ok
          else
            render json: Api::Admin::ErrorSerializationService.new(goods_nomenclature_label).call,
                   status: :unprocessable_content
          end
        end

        def versions
          render json: serialize_versions(goods_nomenclature_label.versions.all)
        end

        private

        def serialize(label, options = {})
          Api::Admin::GoodsNomenclatures::GoodsNomenclatureLabelSerializer
            .new(label, options)
            .serializable_hash
        end

        def serialize_versions(versions)
          Version.preload_predecessors(versions)
          Api::Admin::VersionSerializer.new(versions).serializable_hash
        end

        def goods_nomenclature_label
          @goods_nomenclature_label ||= find_goods_nomenclature_label
        end

        def find_goods_nomenclature_label
          if filter_version_id.present? && !current_version?
            find_historical_label
          else
            find_current_label
          end
        end

        def find_current_label
          label = GoodsNomenclatureLabel
            .where(goods_nomenclature_item_id: goods_nomenclature_item_id)
            .first

          raise Sequel::RecordNotFound if label.blank?

          label
        end

        def find_historical_label
          version = versions_for_item
            .where(id: filter_version_id)
            .first

          raise Sequel::RecordNotFound if version.blank?

          version.reify
        end

        def versions_for_item
          Version.where(item_type: 'GoodsNomenclatureLabel', item_id: label_sid_for_versions)
        end

        def label_sid_for_versions
          @label_sid_for_versions ||= GoodsNomenclatureLabel
            .where(goods_nomenclature_item_id: goods_nomenclature_item_id)
            .get(:goods_nomenclature_sid)
            &.to_s
        end

        def goods_nomenclature
          @goods_nomenclature ||= begin
            gn = TimeMachine.now do
              GoodsNomenclature
                .actual
                .where(goods_nomenclature_sid: goods_nomenclature_label.goods_nomenclature_sid)
                .first
            end

            raise Sequel::RecordNotFound if gn.blank?

            gn
          end
        end

        def goods_nomenclature_item_id
          params[:goods_nomenclature_id]
        end

        def reindex_goods_nomenclature
          TradeTariffBackend.search_client.index(
            ::Search::GoodsNomenclatureIndex,
            goods_nomenclature.reload,
          )
          update_label_suggestions
        end

        def update_label_suggestions
          LabelSuggestionsUpdaterService.new(goods_nomenclature).call
        end

        def label_params
          attributes = params.require(:data).require(:attributes)
          labels_data = attributes[:labels]

          return {} if labels_data.blank?

          {
            description: labels_data[:description],
            known_brands: Sequel.pg_array(Array(labels_data[:known_brands]), :text),
            colloquial_terms: Sequel.pg_array(Array(labels_data[:colloquial_terms]), :text),
            synonyms: Sequel.pg_array(Array(labels_data[:synonyms]), :text),
            labels: {
              'original_description' => goods_nomenclature_label.original_description,
              'description' => labels_data[:description],
              'known_brands' => Array(labels_data[:known_brands]),
              'colloquial_terms' => Array(labels_data[:colloquial_terms]),
              'synonyms' => Array(labels_data[:synonyms]),
            },
          }
        end
      end
    end
  end
end
