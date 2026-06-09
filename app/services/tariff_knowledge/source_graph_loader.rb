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
      update = latest_approved_update
      return unless update

      SOURCE_TYPES.each do |source_type|
        sources_for(source_type, update).each do |source|
          load_source(source_type, source)
        end
      end
    end

  private

    def latest_approved_update
      CustomsTariffUpdate
        .actual
        .approved
        .order(Sequel.desc(:validity_start_date))
        .first
    end

    def sources_for(source_type, update)
      source_type[:model]
        .approved
        .where(customs_tariff_update_version: update.version)
    end

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
      now = Time.zone.now
      values = attributes.merge(
        metadata: Sequel.pg_jsonb(attributes.fetch(:metadata, { 'loader' => self.class.name })),
        created_at: now,
        updated_at: now,
      )

      Node.dataset
          .insert_conflict(target: :key, update: node_update_values)
          .insert(values)

      Node.by_key(key).first
    end

    def upsert_edge(source_node, target_node, relationship_type)
      now = Time.zone.now
      values = {
        source_node_id: source_node.id,
        target_node_id: target_node.id,
        relationship_type:,
        metadata: Sequel.pg_jsonb({ 'loader' => self.class.name }),
        created_at: now,
        updated_at: now,
      }

      Edge.dataset
          .insert_conflict(target: %i[source_node_id target_node_id relationship_type], update: edge_update_values)
          .insert(values)
    end

    def node_update_values
      {
        node_type: Sequel[:excluded][:node_type],
        title: Sequel[:excluded][:title],
        content: Sequel[:excluded][:content],
        metadata: Sequel[:excluded][:metadata],
        source_type: Sequel[:excluded][:source_type],
        source_id: Sequel[:excluded][:source_id],
        source_version: Sequel[:excluded][:source_version],
        goods_nomenclature_sid: Sequel[:excluded][:goods_nomenclature_sid],
        goods_nomenclature_item_id: Sequel[:excluded][:goods_nomenclature_item_id],
        producline_suffix: Sequel[:excluded][:producline_suffix],
        goods_nomenclature_type: Sequel[:excluded][:goods_nomenclature_type],
        validity_start_date: Sequel[:excluded][:validity_start_date],
        validity_end_date: Sequel[:excluded][:validity_end_date],
        updated_at: Sequel[:excluded][:updated_at],
      }
    end

    def edge_update_values
      {
        metadata: Sequel[:excluded][:metadata],
        updated_at: Sequel[:excluded][:updated_at],
      }
    end
  end
end
