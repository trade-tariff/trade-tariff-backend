module Api
  module Admin
    module GoodsNomenclatures
      class GoodsNomenclatureLabelsController < AdminController
        def show
          render json: serialize(goods_nomenclature_label)
        end

        def update
          goods_nomenclature_label.set(label_params.merge(manually_edited: true))

          if goods_nomenclature_label.save(raise_on_failure: false)
            reindex_goods_nomenclature
            render json: serialize(goods_nomenclature_label.reload), status: :ok
          else
            render json: Api::Admin::ErrorSerializationService.new(goods_nomenclature_label).call,
                   status: :unprocessable_content
          end
        end

        private

        def serialize(label)
          Api::Admin::GoodsNomenclatures::GoodsNomenclatureLabelSerializer
            .new(label)
            .serializable_hash
        end

        def goods_nomenclature_label
          @goods_nomenclature_label ||= find_goods_nomenclature_label
        end

        def find_goods_nomenclature_label
          label = GoodsNomenclatureLabel
            .where(goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid)
            .first

          raise Sequel::RecordNotFound if label.blank?

          label
        end

        def goods_nomenclature
          @goods_nomenclature ||= find_goods_nomenclature
        end

        def find_goods_nomenclature
          gn = TimeMachine.now do
            GoodsNomenclature
              .actual
              .where(goods_nomenclature_item_id: goods_nomenclature_item_id)
              .first
          end

          raise Sequel::RecordNotFound if gn.blank?

          gn
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
          labels = attributes[:labels]

          return {} if labels.blank?

          {
            labels: {
              'original_description' => goods_nomenclature_label.labels&.dig('original_description'),
              'description' => labels[:description],
              'known_brands' => Array(labels[:known_brands]),
              'colloquial_terms' => Array(labels[:colloquial_terms]),
              'synonyms' => Array(labels[:synonyms]),
            },
          }
        end
      end
    end
  end
end
