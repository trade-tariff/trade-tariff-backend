module Api
  module Admin
    module GoodsNomenclatures
      class GoodsNomenclatureSelfTextsController < AdminController
        def show
          render json: serialize(self_text_record)
        end

        def update
          self_text_record.set(update_params)
          self_text_record.save_changes

          render json: serialize(self_text_record.reload), status: :ok
        end

        def score
          SelfTextConfidenceScorer.new.score([self_text_record.goods_nomenclature_sid])

          render json: serialize(self_text_record.reload), status: :ok
        end

        def approve
          self_text_record.update(needs_review: false)

          render json: serialize(self_text_record.reload), status: :ok
        end

        def reject
          self_text_record.update(needs_review: true)

          render json: serialize(self_text_record.reload), status: :ok
        end

        def regenerate
          gn = TimeMachine.now do
            GoodsNomenclature.actual
              .where(goods_nomenclature_item_id: params[:goods_nomenclature_id])
              .first
          end

          raise Sequel::RecordNotFound unless gn

          chapter = TimeMachine.now { Chapter.actual.by_code(gn.goods_nomenclature_item_id[0..1]).take }
          raise Sequel::RecordNotFound unless chapter

          # Force regeneration by clearing context hash so skip? returns false
          self_text_record.update(context_hash: nil, stale: true)

          GenerateSelfText::AiBuilder.call(chapter)

          render json: serialize(self_text_record.reload), status: :ok
        end

        private

        def serialize(record)
          GoodsNomenclatureSelfTextSerializer.new(record).serializable_hash
        end

        def self_text_record
          @self_text_record ||= GoodsNomenclatureSelfText
            .where(goods_nomenclature_item_id: params[:goods_nomenclature_id])
            .first || raise(Sequel::RecordNotFound)
        end

        def update_params
          attributes = params.require(:data).require(:attributes)
          {
            self_text: attributes[:self_text],
            manually_edited: true,
            needs_review: false,
          }
        end
      end
    end
  end
end
