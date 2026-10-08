module Api
  module Admin
    module Search
      module Evaluation
        # One source item of a set. It stands for three gold queries, one per persona, so the
        # queries and notes are flat attributes named after their persona, for example
        # emu_generic_query. The id is "<source type>-<source id>".
        class GoldQuerySetItemSerializer
          include JSONAPI::Serializer

          set_type :gold_query_set_item
          set_id :id

          attributes :gold_query_set_id,
                     :source_type,
                     :source_id,
                     :real_user_search,
                     :expected_code,
                     :oracle_text

          ::Evaluation::GoldQueryItem::PERSONAS.each do |persona|
            attribute(:"#{persona}_query") { |item| item.query_for(persona) }
            attribute(:"#{persona}_notes") { |item| item.notes_for(persona) }
          end
        end
      end
    end
  end
end
