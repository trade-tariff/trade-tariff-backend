module TariffKnowledge
  class SourceGraphLoader
    RangeReference = Data.define(:type, :code)

    SOURCE_TYPES = [
      {
        model: CustomsTariffChapterNote,
        label: 'customs_tariff_chapter_note',
        identifier: :chapter_id,
        title: ->(note) { "Chapter #{note.chapter_id} notes" },
      },
      {
        model: CustomsTariffSectionNote,
        label: 'customs_tariff_section_note',
        identifier: :section_id,
        title: ->(note) { "Section #{note.section_id} notes" },
      },
      {
        model: CustomsTariffGeneralRule,
        label: 'customs_tariff_general_rule',
        identifier: :rule_label,
        title: ->(note) { "GIR #{note.rule_label}" },
      },
    ].freeze

    def self.call
      new.call
    end

    def call
      SOURCE_TYPES.each do |source_type|
        source_type[:model].approved.each do |source|
          load_source(source_type, source)
        end
      end
    end

  private

    def load_source(source_type, source)
      source_node = upsert_node(
        node_type: Node::NOTE_SOURCE,
        key: source_key(source_type, source),
        title: source_type[:title].call(source),
        content: source.content,
        source_type: source_type[:label],
        source_id: source.public_send(source_type[:identifier]).to_s,
        source_version: source.customs_tariff_update_version,
      )

      fragments(source.content).each.with_index(1) do |fragment_content, index|
        load_fragment(source_type, source, source_node, fragment_content, index)
      end
    end

    def load_fragment(source_type, source, source_node, content, index)
      fragment_node = upsert_node(
        node_type: Node::NOTE_FRAGMENT,
        key: "#{source_key(source_type, source)}:#{sprintf('%04d', index)}".sub('note_source:', 'note_fragment:'),
        title: "#{source_node.title} fragment #{index}",
        content:,
        source_type: source_type[:label],
        source_id: source_node.source_id,
        source_version: source.customs_tariff_update_version,
      )
      upsert_edge(source_node, fragment_node, Edge::CONTAINS)

      range_references(content).each do |reference|
        range_node = upsert_range_node(reference)
        upsert_edge(fragment_node, range_node, Edge::REFERENCES)
        expand_range(range_node, reference)
      end
    end

    def fragments(content)
      content.to_s.split(/\n{2,}|(?<=[.!?])\s+/).map(&:strip).reject(&:blank?)
    end

    def range_references(content)
      references = content.to_s.scan(/\b(chapter|heading)\s+(\d{2}|\d{4})\b/i).filter_map do |type, code|
        next if negated_reference?(content)

        RangeReference.new(type: type.downcase, code:)
      end

      references.uniq
    end

    def negated_reference?(content)
      content.match?(/\b(excluded|excluding|does not include|do not include)\b/i)
    end

    def upsert_range_node(reference)
      upsert_node(
        node_type: Node::RANGE,
        key: "range:#{reference.type}:#{reference.code}",
        title: "#{reference.type.titleize} #{reference.code}",
        content: nil,
        metadata: { 'range_type' => reference.type, 'code' => reference.code },
      )
    end

    def expand_range(range_node, reference)
      matching_declarable_nodes(reference).each do |declarable_node|
        upsert_edge(range_node, declarable_node, Edge::EXPANDS_TO)
      end
    end

    def matching_declarable_nodes(reference)
      Node.goods_nomenclatures
          .where(Sequel.like(:goods_nomenclature_item_id, "#{reference.code}%"))
          .all
    end

    def source_key(source_type, source)
      identifier = source.public_send(source_type[:identifier])
      "note_source:#{source_type[:label]}:#{source.customs_tariff_update_version}:#{identifier}"
    end

    def upsert_node(attributes)
      key = attributes.fetch(:key)
      node = Node.by_key(key).first
      now = Time.zone.now
      values = attributes.merge(
        metadata: Sequel.pg_jsonb(attributes.fetch(:metadata, { 'loader' => self.class.name })),
        updated_at: now,
      )

      if node
        node.update(values)
      else
        Node.create(values.merge(created_at: now))
      end
    end

    def upsert_edge(source_node, target_node, relationship_type)
      edge = Edge.where(
        source_node_id: source_node.id,
        target_node_id: target_node.id,
        relationship_type:,
      ).first
      now = Time.zone.now
      values = { metadata: Sequel.pg_jsonb({ 'loader' => self.class.name }), updated_at: now }

      if edge
        edge.update(values)
      else
        Edge.create(values.merge(source_node_id: source_node.id, target_node_id: target_node.id, relationship_type:, created_at: now))
      end
    end
  end
end
