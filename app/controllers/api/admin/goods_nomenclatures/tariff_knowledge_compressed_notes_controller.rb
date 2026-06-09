module Api
  module Admin
    module GoodsNomenclatures
      class TariffKnowledgeCompressedNotesController < AdminController
        include Api::Admin::VersionBrowsing

        def show
          render json: serialize(viewed_compressed_note, serializer_options)
        end

        def update
          compressed_note.apply_manual_edit!(update_params)

          render json: serialize(compressed_note.reload, serializer_options), status: :ok
        end

        def approve
          compressed_note.approve!

          render json: serialize(compressed_note.reload), status: :ok
        end

        def reject
          compressed_note.mark_needs_review!

          render json: serialize(compressed_note.reload), status: :ok
        end

        def regenerate
          compressed_note.prepare_ui_regeneration!(context_hash: 'invalidated')
          TariffKnowledge::CompressedNoteGenerator.call(goods_nomenclature_sids: [goods_nomenclature_sid])

          render json: serialize(compressed_note.reload), status: :ok
        end

        def versions
          render json: serialize_versions(compressed_note.versions.all)
        end

      private

        def serialize(note, options = {})
          Api::Admin::TariffKnowledgeCompressedNoteSerializer
            .new(note, options)
            .serializable_hash
        end

        def serialize_versions(versions)
          Version.preload_predecessors(versions)
          Api::Admin::VersionSerializer.new(versions).serializable_hash
        end

        def compressed_note
          @compressed_note ||= find_current_compressed_note
        end

        def viewed_compressed_note
          if filter_version_id.present? && !current_version?
            find_historical_compressed_note
          else
            find_current_compressed_note
          end
        end

        def find_current_compressed_note
          TariffKnowledge::CompressedNote[goods_nomenclature_sid] || raise(Sequel::RecordNotFound)
        end

        def find_historical_compressed_note
          version = versions_for_item
            .where(id: filter_version_id)
            .first

          raise Sequel::RecordNotFound if version.blank?

          version.reify
        end

        def versions_for_item
          Version.where(item_type: 'TariffKnowledge::CompressedNote', item_id: goods_nomenclature_sid.to_s)
        end

        def goods_nomenclature_sid
          params[:goods_nomenclature_id].to_i
        end

        def update_params
          attributes = params.require(:data).require(:attributes)
          {
            content: attributes[:content],
          }
        end
      end
    end
  end
end
