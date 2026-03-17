module Api
  module Admin
    module GoodsNomenclatures
      class GoodsNomenclatureSelfTextsController < AdminController
        include Api::Admin::VersionBrowsing

        def show
          render json: serialize(self_text_record, serializer_options)
        end

        def update
          self_text_record.set(update_params)
          self_text_record.save_changes
          ScoreLabelBatchWorker.perform_async(self_text_record.goods_nomenclature_sid)

          render json: serialize(self_text_record.reload, serializer_options), status: :ok
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

        def versions
          render json: serialize_versions(self_text_record.versions.all)
        end

        def regenerate
          gn = TimeMachine.now do
            GoodsNomenclature.actual
              .where(Sequel[:goods_nomenclatures][:goods_nomenclature_sid] => params[:goods_nomenclature_id].to_i)
              .first
          end

          raise Sequel::RecordNotFound unless gn

          chapter = TimeMachine.now { Chapter.actual.by_code(gn.goods_nomenclature_item_id[0..1]).take }
          raise Sequel::RecordNotFound unless chapter

          # Force regeneration by invalidating context hash so context_stale? returns true
          self_text_record.update(context_hash: 'invalidated', stale: true)

          GenerateSelfText::OtherSelfTextBuilder.call(chapter)
          GenerateSelfText::NonOtherSelfTextBuilder.call(chapter)
          ScoreLabelBatchWorker.perform_async(self_text_record.goods_nomenclature_sid)

          render json: serialize(self_text_record.reload), status: :ok
        end

        private

        def serialize(record, options = {})
          GoodsNomenclatureSelfTextSerializer.new(record, options).serializable_hash
        end

        def serialize_versions(versions)
          Version.preload_predecessors(versions)
          Api::Admin::VersionSerializer.new(versions).serializable_hash
        end

        def self_text_record
          @self_text_record ||= find_self_text_record
        end

        def find_self_text_record
          if filter_version_id.present? && !current_version?
            find_historical_self_text
          else
            find_current_self_text
          end
        end

        def find_current_self_text
          GoodsNomenclatureSelfText
            .where(goods_nomenclature_sid: params[:goods_nomenclature_id].to_i)
            .first || raise(Sequel::RecordNotFound)
        end

        def find_historical_self_text
          version = versions_for_item
            .where(id: filter_version_id)
            .first

          raise Sequel::RecordNotFound if version.blank?

          version.reify
        end

        def versions_for_item
          Version.where(item_type: 'GoodsNomenclatureSelfText', item_id: params[:goods_nomenclature_id].to_s)
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
