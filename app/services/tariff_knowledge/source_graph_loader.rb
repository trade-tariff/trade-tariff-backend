module TariffKnowledge
  class SourceGraphLoader
    BATCH_SIZE = 500

    # Tariff notes often use nested list markers such as "a.", "ii.", "ij.",
    # and "1.". These patterns identify standalone markers and markers stranded
    # at the end of a split fragment so we can merge them back into the following
    # legal text. They intentionally anchor to the whole fragment to avoid
    # treating ordinary prose as a list marker.
    LIST_MARKER_PATTERN = /\A(?:ij|\(?[a-z]\)?|[ivx]+|\d+)\.\z/i
    TRAILING_LIST_MARKER_PATTERN = /\A(.+?)\s+((?:ij|\(?[a-z]\)?|[ivx]+|\d+)\.)\z/im
    USABLE_UPDATE_STATUSES = [CustomsTariffUpdate::APPROVED].freeze
    USABLE_SOURCE_STATUSES = %w[approved].freeze

    RangeReference = Data.define(:type, :code)
    SourceAssociation = Data.define(:association, :label, :identifier, :title)

    SOURCE_ASSOCIATIONS = [
      SourceAssociation.new(
        association: :customs_tariff_chapter_notes,
        label: 'customs_tariff_chapter_note',
        identifier: :chapter_id,
        title: ->(source) { "Chapter #{source.chapter_id} notes" },
      ),
      SourceAssociation.new(
        association: :customs_tariff_section_notes,
        label: 'customs_tariff_section_note',
        identifier: :section_id,
        title: ->(source) { "Section #{source.section_id} notes" },
      ),
      SourceAssociation.new(
        association: :customs_tariff_general_rules,
        label: 'customs_tariff_general_rule',
        identifier: :rule_label,
        title: ->(source) { "GIR #{source.rule_label}" },
      ),
    ].freeze

    def self.call
      new.call
    end

    def call
      update = latest_approved_update
      return unless update

      SOURCE_ASSOCIATIONS.each do |source_association|
        sources_for(source_association, update).each do |source|
          load_source(source_association, source)
        end
      end
    end

  private

    def latest_approved_update
      # The graph represents the tariff source set we are prepared to expose to
      # generated classification context. Use one approved update snapshot only;
      # mixing pending files or older approved files would make note provenance
      # hard to reason about and could surface source text that is not current.
      TimeMachine.at(@time_machine_date ||= Time.current) do
        CustomsTariffUpdate
          .actual
          .where(status: USABLE_UPDATE_STATUSES)
          .order(Sequel.desc(:validity_start_date))
          .first
      end
    end

    def sources_for(source_association, update)
      TimeMachine.at(@time_machine_date ||= Time.current) { approved_sources_for_update(source_association, update) }
    end

    def approved_sources_for_update(source_association, update)
      update.public_send(:"#{source_association.association}_dataset")
            .where(status: USABLE_SOURCE_STATUSES)
    end

    def load_source(source_association, source)
      source_node = upsert_node(
        node_type: Node::NOTE_SOURCE,
        key: source_key(source_association, source),
        title: source_association.title.call(source),
        content: source.content,
        source_type: source_association.label,
        source_id: source.public_send(source_association.identifier).to_s,
        source_version: source.customs_tariff_update_version,
      )

      fragment_nodes = fragments(source.content).map.with_index(1) do |fragment_content, index|
        load_fragment(source_association, source, source_node, fragment_content, index)
      end

      delete_stale_edges(
        source_node:,
        relationship_type: Edge::CONTAINS,
        current_target_node_ids: fragment_nodes.map(&:id),
      )
    end

    def load_fragment(source_association, source, source_node, content, index)
      fragment_node = upsert_node(
        node_type: Node::NOTE_FRAGMENT,
        key: "#{source_key(source_association, source)}:#{sprintf('%04d', index)}".sub('note_source:', 'note_fragment:'),
        title: "#{source_node.title} fragment #{index}",
        content:,
        source_type: source_association.label,
        source_id: source_node.source_id,
        source_version: source.customs_tariff_update_version,
      )
      upsert_edge(source_node, fragment_node, Edge::CONTAINS)

      range_nodes = range_references(content).map do |reference|
        range_node = upsert_range_node(reference)
        upsert_edge(fragment_node, range_node, Edge::REFERENCES)
        expand_range(range_node, reference)
        range_node
      end
      scoped_declarable_nodes = scoped_declarable_nodes_for(source_association, source)
      upsert_edges(fragment_node, scoped_declarable_nodes, Edge::APPLIES_TO)

      delete_stale_edges(
        source_node: fragment_node,
        relationship_type: Edge::REFERENCES,
        current_target_node_ids: range_nodes.map(&:id),
      )
      delete_stale_edges(
        source_node: fragment_node,
        relationship_type: Edge::APPLIES_TO,
        current_target_node_dataset: scoped_declarable_nodes,
      )

      fragment_node
    end

    def fragments(content)
      content
        .to_s
        .split(/\n{2,}|(?<=[.!?])\s+/)
        .map(&:strip)
        .reject(&:blank?)
        .then { |split_fragments| merge_orphaned_list_markers(split_fragments) }
        .then { |split_fragments| merge_dangling_numeric_references(split_fragments) }
    end

    def merge_orphaned_list_markers(split_fragments)
      split_fragments.each_with_object([]) do |fragment, merged|
        fragment = "#{merged.pop} #{fragment}" if list_marker_sequence?(merged.last)
        match = fragment.match(TRAILING_LIST_MARKER_PATTERN)
        text, marker = match&.captures

        if match && !list_marker_sequence?(text.strip)
          merged.push(text.strip, marker)
        else
          merged << (match ? "#{text.strip} #{marker}" : fragment)
        end
      end
    end

    def list_marker_sequence?(fragment)
      fragment.present? && fragment.split.all? { |part| part.match?(LIST_MARKER_PATTERN) }
    end

    def merge_dangling_numeric_references(split_fragments)
      split_fragments.each_with_object([]) do |fragment, merged|
        # Sentence splitting can detach references such as "heading 8481." or
        # "C." from the text that introduces them. Reattach only when the
        # previous fragment ends in wording that normally introduces a legal
        # chapter/heading/rule reference, a digit, or a known year-style number.
        if merged.last && (
          numeric_reference_context?(merged.last, fragment) ||
            (fragment.match?(/\AC\.(?:\s+.+)?\z/i) && merged.last.match?(/\d\z/))
        )
          attach_reference_fragment(fragment, merged)
        else
          merged << fragment
        end
      end
    end

    def attach_reference_fragment(fragment, merged)
      reference, remaining_fragment = fragment.match(/\A((?:\d{1,4}|C)\.)\s*(.*)\z/i).captures
      merged[-1] = "#{merged.last} #{reference}"
      merged << remaining_fragment.strip if remaining_fragment.present?
    end

    def numeric_reference_context?(previous_fragment, fragment)
      fragment.match?(/\A\d{1,4}\.(?:\s+.+)?\z/) &&
        (
          previous_fragment.match?(/\b(?:heading|headings|chapter|chapters|rule|rules|and|or|to)\z/i) ||
            previous_fragment.match?(/\d\z/) ||
            fragment.match?(/\A(?:19|20)\d{2}\.(?:\s+.+)?\z/)
        )
    end

    def range_references(content)
      references = reference_clauses(content).flat_map do |clause|
        next [] if negated_reference?(clause)

        # Only positive chapter/heading references become range nodes. Negated
        # clauses such as "excluding chapter 39" are classification evidence but
        # should not expand the fragment to every commodity in the excluded range.
        clause.scan(/\b(chapter|heading)\s+(\d{2}|\d{4})\b/i).map do |type, code|
          RangeReference.new(type: type.downcase, code:)
        end
      end

      references.uniq
    end

    def reference_clauses(content)
      content.to_s.split(/[.;]/).map(&:strip).reject(&:blank?)
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
      upsert_edges(range_node, matching_declarable_nodes(reference), Edge::EXPANDS_TO)
    end

    def matching_declarable_nodes(reference)
      Node.goods_nomenclatures
          .where(Sequel.like(:goods_nomenclature_item_id, "#{reference.code}%"))
    end

    def scoped_declarable_nodes_for(source_association, source)
      @scoped_declarable_nodes_by_key ||= {}
      @scoped_declarable_nodes_by_key[[source_association.label, source.public_send(source_association.identifier)]] ||= uncached_scoped_declarable_nodes_for(source_association, source)
    end

    def uncached_scoped_declarable_nodes_for(source_association, source)
      case source_association.label
      when 'customs_tariff_chapter_note'
        scoped_chapter_declarable_nodes([source.chapter_id])
      when 'customs_tariff_section_note'
        scoped_chapter_declarable_nodes(chapter_codes_for_section(source.section_id))
      when 'customs_tariff_general_rule'
        general_rule_declarable_nodes
      else
        empty_declarable_node_dataset
      end
    end

    def empty_declarable_node_dataset
      Node.non_hidden_goods_nomenclatures.where(Sequel.lit('1 = 0'))
    end

    def general_rule_declarable_nodes
      # GIRs apply across the tariff, so this is intentionally the full declarable set.
      @general_rule_declarable_nodes ||= Node.non_hidden_goods_nomenclatures
    end

    def scoped_chapter_declarable_nodes(chapter_codes)
      chapter_codes = normalize_chapter_codes(chapter_codes)
      return empty_declarable_node_dataset if chapter_codes.empty?

      direct_conditions = chapter_codes.map { |code| Sequel.like(:goods_nomenclature_item_id, "#{code}%") }
      Node.non_hidden_goods_nomenclatures.where(Sequel.|(*direct_conditions))
    end

    def chapter_codes_for_section(section_id)
      Chapter
        .association_join(:sections)
        .where(sections__id: section_id)
        .select_map(:goods_nomenclature_item_id)
        .map { |item_id| item_id.first(2) }
        .uniq
    end

    def normalize_chapter_codes(chapter_codes)
      chapter_codes.map { |code| sprintf('%02d', code.to_i) }.uniq
    end

    def source_key(source_association, source)
      identifier = source.public_send(source_association.identifier)
      "note_source:#{source_association.label}:#{source.customs_tariff_update_version}:#{identifier}"
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

    def upsert_edges(source_node, target_nodes, relationship_type)
      target_node_batches(target_nodes).each do |nodes|
        now = Time.zone.now
        rows = nodes.map do |target_node|
          {
            source_node_id: source_node.id,
            target_node_id: target_node.id,
            relationship_type:,
            metadata: Sequel.pg_jsonb({ 'loader' => self.class.name }),
            created_at: now,
            updated_at: now,
          }
        end

        Edge.dataset
            .insert_conflict(target: %i[source_node_id target_node_id relationship_type], update: edge_update_values)
            .multi_insert(rows)
      end
    end

    def target_node_batches(target_nodes)
      return target_nodes.each_slice(BATCH_SIZE) unless target_nodes.respond_to?(:paged_each)

      Enumerator.new do |yielder|
        batch = []
        target_nodes.paged_each(rows_per_fetch: BATCH_SIZE) do |target_node|
          batch << target_node
          next unless batch.size == BATCH_SIZE

          yielder << batch
          batch = []
        end
        yielder << batch if batch.any?
      end
    end

    def delete_stale_edges(source_node:, relationship_type:, current_target_node_ids: [], current_target_node_dataset: nil)
      dataset = Edge.where(
        source_node_id: source_node.id,
        relationship_type:,
      )
      if current_target_node_dataset
        dataset = dataset.exclude(target_node_id: current_target_node_dataset.select(:id))
      elsif current_target_node_ids.any?
        dataset = dataset.exclude(target_node_id: current_target_node_ids)
      end
      dataset.delete
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
