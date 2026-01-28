module Api
  module Admin
    module GoodsNomenclatures
      class GoodsNomenclatureLabelsController < AdminController
        def show
          render json: serialize(goods_nomenclature_label, serializer_options)
        end

        def update
          goods_nomenclature_label.set(label_params)

          if goods_nomenclature_label.save_update
            render json: serialize(goods_nomenclature_label.reload, serializer_options), status: :ok
          else
            render json: Api::Admin::ErrorSerializationService.new(goods_nomenclature_label).call,
                   status: :unprocessable_content
          end
        end

        private

        def serialize(label, options = {})
          Api::Admin::GoodsNomenclatures::GoodsNomenclatureLabelSerializer
            .new(label, options)
            .serializable_hash
        end

        def serializer_options
          { meta: version_meta }
        end

        def version_meta
          {
            version: {
              current: current_version?,
              oid: current_oid,
              previous_oid: previous_oid,
              has_previous_version: previous_oid.present?,
            },
          }
        end

        def current_oid
          @current_oid ||= viewed_operation&.oid
        end

        def previous_oid
          return @previous_oid if defined?(@previous_oid)

          viewed_oid = viewed_operation&.oid
          return @previous_oid = nil if viewed_oid.blank?

          # Find the operation before the one being viewed
          @previous_oid = GoodsNomenclatureLabel::Operation
            .where(goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid)
            .where(Sequel.lit('oid < ?', viewed_oid))
            .order(Sequel.desc(:oid))
            .get(:oid)
        end

        def viewed_operation
          @viewed_operation ||= if filter_oid.present?
                                  # Historical: find the operation just before the filter_oid
                                  GoodsNomenclatureLabel::Operation
                                    .where(goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid)
                                    .where(Sequel.lit('oid < ?', filter_oid))
                                    .order(Sequel.desc(:oid))
                                    .first
                                else
                                  # Current: the latest operation
                                  GoodsNomenclatureLabel::Operation
                                    .where(goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid)
                                    .order(Sequel.desc(:oid))
                                    .first
                                end
        end

        def current_version?
          filter_oid.blank?
        end

        def goods_nomenclature_label
          @goods_nomenclature_label ||= find_goods_nomenclature_label
        end

        def find_goods_nomenclature_label
          label = if filter_oid.present?
                    find_historical_label
                  else
                    find_current_label
                  end

          raise Sequel::RecordNotFound if label.blank?

          label
        end

        def find_current_label
          TimeMachine.now do
            GoodsNomenclatureLabel
              .actual
              .where(goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid)
              .first
          end
        end

        def find_historical_label
          operation = GoodsNomenclatureLabel::Operation
            .where(goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid)
            .where(Sequel.lit('oid < ?', filter_oid))
            .order(Sequel.desc(:oid))
            .first

          raise Sequel::RecordNotFound if operation.blank?

          operation.record_from_oplog
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

        def filter_oid
          params.dig(:filter, :oid)&.to_i
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
