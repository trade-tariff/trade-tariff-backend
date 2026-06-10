module TariffKnowledge
  class CompressedNoteGenerator
    def self.call(goods_nomenclature_sids:)
      new(goods_nomenclature_sids).call
    end

    def initialize(goods_nomenclature_sids)
      @goods_nomenclature_sids = goods_nomenclature_sids
    end

    def call
      nodes = declarable_nodes
      evidence_by_node_id = evidence_by_declarable_node_id(nodes)

      nodes.filter_map do |declarable_node|
        generate_for(declarable_node, evidence_by_node_id.fetch(declarable_node.id, []))
      end
    end

  private

    attr_reader :goods_nomenclature_sids

    def declarable_nodes
      Node.goods_nomenclatures
          .where(goods_nomenclature_sid: goods_nomenclature_sids)
          .all
    end

    def generate_for(declarable_node, evidence)
      return if evidence.empty?

      content = content_for(declarable_node, evidence)
      attributes = {
        goods_nomenclature_item_id: declarable_node.goods_nomenclature_item_id,
        producline_suffix: declarable_node.producline_suffix,
        goods_nomenclature_type: declarable_node.goods_nomenclature_type,
        content:,
        metadata: Sequel.pg_jsonb(metadata_for(evidence)),
        context_hash: Digest::SHA256.hexdigest(content),
        generated_at: Time.zone.now,
        needs_review: false,
        approved: false,
        manually_edited: false,
        stale: false,
        expired: false,
      }

      upsert_note(declarable_node, attributes)
    end

    def evidence_by_declarable_node_id(declarable_nodes)
      declarable_node_ids = declarable_nodes.map(&:id)
      return {} if declarable_node_ids.empty?

      # Evidence can reach a declarable commodity in two ways:
      # - directly, via APPLIES_TO from a note fragment to the commodity
      # - indirectly, where a fragment REFERENCES a chapter/heading range and
      #   that range EXPANDS_TO the commodity.
      #
      # When both paths exist, keep the range-aware evidence because it tells the
      # prompt selector which candidate chapter/heading made the fragment useful.
      expansion_edges = Edge.by_relationship(Edge::EXPANDS_TO).where(target_node_id: declarable_node_ids).all
      range_nodes = nodes_by_id(expansion_edges.map(&:source_node_id), Node.where(node_type: Node::RANGE))
      reference_edges = Edge.by_relationship(Edge::REFERENCES).where(target_node_id: range_nodes.keys).all
      apply_edges = Edge.by_relationship(Edge::APPLIES_TO).where(target_node_id: declarable_node_ids).all
      fragment_nodes = nodes_by_id((reference_edges + apply_edges).map(&:source_node_id), Node.note_fragments)
      expansion_edges_by_target_id = expansion_edges.group_by(&:target_node_id)
      reference_edges_by_range_id = reference_edges.group_by(&:target_node_id)
      apply_edges_by_target_id = apply_edges.group_by(&:target_node_id)
      source_nodes_by_fragment_id = source_nodes_by_fragment_node_id(fragment_nodes.values)

      declarable_nodes.each_with_object({}) do |declarable_node, grouped|
        applicable_fragment_ids = apply_edges_by_target_id.fetch(declarable_node.id, []).map(&:source_node_id).to_set

        referenced_evidence = expansion_edges_by_target_id
          .fetch(declarable_node.id, [])
          .flat_map do |edge|
            range_node = range_nodes[edge.source_node_id]
            reference_edges_by_range_id.fetch(range_node&.id, []).filter_map do |reference_edge|
              fragment_node = fragment_nodes[reference_edge.source_node_id]
              if fragment_node && applicable_fragment_ids.include?(fragment_node.id)
                [fragment_node, range_node, source_nodes_by_fragment_id[fragment_node.id]]
              end
            end
          end

        referenced_fragment_node_ids = referenced_evidence.map { |fragment_node, _range_node, _source_node| fragment_node.id }.to_set
        applied_evidence = applicable_fragment_ids.filter_map do |fragment_node_id|
          next if referenced_fragment_node_ids.include?(fragment_node_id)

          fragment_node = fragment_nodes[fragment_node_id]
          [fragment_node, nil, source_nodes_by_fragment_id[fragment_node_id]] if fragment_node
        end
        evidence = (referenced_evidence + applied_evidence)
          .uniq { |fragment_node, range_node, _source_node| [fragment_node.id, range_node&.id] }
        grouped[declarable_node.id] = sort_evidence(evidence) if evidence.any?
      end
    end

    def nodes_by_id(ids, dataset)
      ids = ids.compact.uniq
      ids.empty? ? {} : dataset.where(id: ids).all.index_by(&:id)
    end

    def source_nodes_by_fragment_node_id(fragment_nodes)
      fragment_node_ids = fragment_nodes.map(&:id).uniq
      return {} if fragment_node_ids.empty?

      contains_edges = Edge.by_relationship(Edge::CONTAINS).where(target_node_id: fragment_node_ids).all
      source_nodes = nodes_by_id(contains_edges.map(&:source_node_id), Node.where(node_type: Node::NOTE_SOURCE))
      contains_edges.each_with_object({}) do |edge, grouped|
        grouped[edge.target_node_id] = source_nodes[edge.source_node_id]
      end
    end

    def sort_evidence(evidence)
      evidence.sort_by do |fragment_node, range_node, _source_node|
        [fragment_node.source_type.to_s, fragment_node.source_id.to_s, fragment_node.key, range_node&.key.to_s]
      end
    end

    def content_for(declarable_node, evidence)
      general_rule_evidence, note_evidence = evidence.partition do |fragment_node, _range_node, _source_node|
        general_rule_fragment?(fragment_node)
      end
      proxy_chapter_evidence, note_evidence = note_evidence.partition do |fragment_node, _range_node, _source_node|
        broad_proxy_chapter_fragment?(declarable_node, fragment_node)
      end
      content = note_evidence.map { |fragment_node, _range_node, _source_node|
        "#{fragment_node.title}\n#{fragment_node.content}"
      }.uniq
      content << proxy_chapter_summary(proxy_chapter_evidence) if proxy_chapter_evidence.any?
      content << general_rule_summary(general_rule_evidence) if general_rule_evidence.any?

      content.compact.join("\n\n")
    end

    def general_rule_fragment?(fragment_node)
      fragment_node.source_type == 'customs_tariff_general_rule' ||
        fragment_node.key.include?(':customs_tariff_general_rule:')
    end

    def broad_proxy_chapter_fragment?(declarable_node, fragment_node)
      # Special/proxy codes can represent goods from many CN chapters. Rendering
      # every applicable chapter note would produce huge, mostly unusable notes,
      # so broad multi-chapter provenance is summarised in content and retained
      # in metadata for audit/drill-down.
      proxy_chapter_codes(declarable_node).many? &&
        (fragment_node.source_type == 'customs_tariff_chapter_note' ||
          fragment_node.key.include?(':customs_tariff_chapter_note:')) &&
        proxy_chapter_codes(declarable_node).include?(fragment_node.source_id.to_s.rjust(2, '0'))
    end

    def proxy_chapter_codes(declarable_node)
      @proxy_chapter_codes_by_node_id ||= {}
      @proxy_chapter_codes_by_node_id[declarable_node.id] ||= Array(declarable_node.metadata.to_h['chapter_scope_codes']).map { |code| sprintf('%02d', code.to_i) }.uniq
    end

    def proxy_chapter_summary(evidence)
      chapter_range = compact_chapter_range(evidence.map { |fragment_node, _range_node, _source_node| fragment_node.source_id.to_s.rjust(2, '0') }.uniq.sort)
      "Chapter note provenance for CN #{chapter_range} applies because this special code covers goods from those chapters. " \
        'The full chapter-note fragments are retained in this note provenance; use the underlying CN chapter when detailed legal note text is needed.'
    end

    def compact_chapter_range(chapter_ids)
      return "chapter #{chapter_ids.first}" if chapter_ids.one?

      chapter_numbers = chapter_ids.map(&:to_i)
      if chapter_numbers.each_cons(2).all? { |left, right| right == left + 1 }
        "chapters #{chapter_ids.first} to #{chapter_ids.last}"
      else
        "chapters #{chapter_ids.join(', ')}"
      end
    end

    def general_rule_summary(evidence)
      rule_labels = evidence.map { |fragment_node, _range_node, _source_node| fragment_node.source_id.presence || fragment_node.key.split(':')[3] }.uniq.sort_by { |label| label.to_s.to_i }
      "General Interpretive Rules #{rule_labels.join(', ')} apply when classifying goods. " \
        'The full rule fragments are retained in this note provenance.'
    end

    def metadata_for(evidence)
      {
        'source_node_keys' => evidence.map { |fragment_node, _range_node, _source_node| fragment_node.key }.uniq,
        'range_node_keys' => evidence.filter_map { |_fragment_node, range_node, _source_node| range_node&.key }.uniq,
        'evidence' => evidence.map { |fragment_node, range_node, source_node| evidence_metadata(fragment_node, range_node, source_node) },
      }
    end

    def evidence_metadata(fragment_node, range_node, source_node)
      range_metadata = range_node ? range_node.metadata.to_h : {}
      context = source_context(fragment_node, source_node)

      {
        'source_node_key' => fragment_node.key,
        'source_type' => fragment_node.source_type.to_s.underscore,
        'source_id' => fragment_node.source_id,
        'source_version' => fragment_node.source_version,
        'source_title' => fragment_node.title,
        'parent_source_node_key' => source_node&.key,
        'parent_source_title' => source_node&.title,
        'source_context' => context,
        'context_type' => context_type(context),
        'range_node_key' => range_node&.key,
        'range_type' => range_metadata['range_type'],
        'range_code' => range_metadata['code'],
        'range_title' => range_node&.title,
        'relationships' => relationships_for(range_node),
      }
    end

    def relationships_for(range_node) = range_node ? [Edge::REFERENCES, Edge::EXPANDS_TO, Edge::APPLIES_TO] : [Edge::APPLIES_TO]

    def source_context(fragment_node, source_node)
      return fragment_node.content.to_s.squish unless source_node

      # A fragment can be a short list item whose meaning depends on the lead-in
      # immediately before it, for example "This chapter does not cover:".
      # Include that lead-in in metadata so prompt-time selection can classify
      # the fragment as inclusion/exclusion/reference without sending the whole
      # source note.
      fragment_nodes = source_fragment_nodes(source_node)
      fragment_index = fragment_nodes.index { |node| node.id == fragment_node.id }
      return fragment_node.content.to_s.squish unless fragment_index

      preceding_fragments = fragment_nodes.first(fragment_index).map { |node| node.content.to_s.squish }
      preceding_fragment = preceding_fragments.reverse.find { |fragment| context_lead_in?(fragment) } || preceding_fragments.last

      [preceding_fragment, fragment_node.content].compact_blank.join(' ').squish
    end

    def source_fragment_nodes(source_node)
      @source_fragment_nodes_by_source_node_id ||= {}
      @source_fragment_nodes_by_source_node_id[source_node.id] ||= begin
        contains_edges = Edge.by_relationship(Edge::CONTAINS).where(source_node_id: source_node.id).all
        fragment_nodes = nodes_by_id(contains_edges.map(&:target_node_id), Node.note_fragments)
        contains_edges.filter_map { |edge| fragment_nodes[edge.target_node_id] }
                      .sort_by { |node| [fragment_sequence(node), node.key.to_s, node.id] }
      end
    end

    def fragment_sequence(fragment_node) = fragment_node.key.to_s[/:(\d+)\z/, 1].to_i

    def context_lead_in?(fragment) = fragment.match?(/:\z|\b(does not cover|not cover|excluded|excluding|does not include|do not include|includes|include|covers|cover)\b/i)

    def context_type(context)
      if context.match?(/\b(does not cover|not cover|excluded|excluding|does not include|do not include)\b/i)
        'exclusion'
      elsif context.match?(/\b(includes|include|covers|cover)\b/i)
        'inclusion'
      else
        'reference'
      end
    end

    def upsert_note(declarable_node, attributes)
      note = CompressedNote[declarable_node.goods_nomenclature_sid]
      return note if note&.manually_edited

      if note
        note.update(attributes)
      else
        CompressedNote.create(attributes.merge(goods_nomenclature_sid: declarable_node.goods_nomenclature_sid))
      end
    end
  end
end
