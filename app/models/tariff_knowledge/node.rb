module TariffKnowledge
  class Node < Sequel::Model(:tariff_knowledge_nodes)
    plugin :timestamps, update_on_create: true
    plugin :auto_validations, not_null: :presence
    plugin :has_paper_trail

    GOODS_NOMENCLATURE = 'goods_nomenclature'.freeze
    SECTION = 'section'.freeze
    NOTE_SOURCE = 'note_source'.freeze
    NOTE_FRAGMENT = 'note_fragment'.freeze
    RANGE = 'range'.freeze
    COMPRESSED_NOTE = 'compressed_note'.freeze

    one_to_many :outgoing_edges,
                class: 'TariffKnowledge::Edge',
                key: :source_node_id
    one_to_many :incoming_edges,
                class: 'TariffKnowledge::Edge',
                key: :target_node_id

    dataset_module do
      def by_key(key)
        where(key:)
      end

      def goods_nomenclatures
        where(node_type: GOODS_NOMENCLATURE)
      end

      def note_fragments
        where(node_type: NOTE_FRAGMENT)
      end
    end

    def validate
      super
      validates_presence :node_type
      validates_presence :key
    end
  end
end
