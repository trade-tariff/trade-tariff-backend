module TariffKnowledge
  class NoteIngestion
    def self.call(sources:)
      new(sources).call
    end

    def initialize(sources)
      @sources = sources
    end

    def call
      Node.db.transaction do
        sources.each { |source| ingest_source(source) }
      end
    end

  private

    attr_reader :sources

    def ingest_source(source)
      source_node = upsert_note_source(source)
      source_declarables = declarables_for_scope(source.scope_type, source.scope_id)

      RuleExtractor.call(source:).each do |rule|
        rule_node = upsert_rule(rule)
        NodeRepository.upsert_edge(source_node, rule_node, Edge::HAS_FRAGMENT, rule_metadata(rule))
        connect_rule_to_declarables(rule_node, source_declarables, 'source_scope')

        referenced_declarables = rule.references.flat_map { |reference| declarables_for_reference(reference) }.uniq(&:goods_nomenclature_sid)
        connect_rule_to_declarables(rule_node, referenced_declarables, 'referenced_by_rule')
        connect_rule_to_references(rule_node, referenced_declarables, rule)
      end
    end

    def upsert_note_source(source)
      NodeRepository.upsert_node(
        key: "note_source:#{source.key}",
        node_type: Node::NOTE_SOURCE,
        title: source.title,
        content: source.content,
        source_type: source.source_type,
        source_id: source.source_id,
        source_version: source.source_version,
        validity_start_date: source.validity_start_date,
        validity_end_date: source.validity_end_date,
        metadata: {
          'scope_type' => source.scope_type,
          'scope_id' => source.scope_id,
        },
      )
    end

    def upsert_rule(rule)
      NodeRepository.upsert_node(
        key: "rule:#{rule.source.key}:#{rule.rule_label}",
        node_type: Node::RULE,
        title: rule.title,
        content: clean_content(rule.content),
        source_type: rule.source.source_type,
        source_id: rule.source.source_id,
        source_version: rule.source.source_version,
        status: Node::GENERATED,
        needs_review: true,
        generated_at: Time.zone.now,
        validity_start_date: rule.source.validity_start_date,
        validity_end_date: rule.source.validity_end_date,
        context_hash: Digest::SHA256.hexdigest([rule.rule_type, rule.content, rule.references].to_json),
        metadata: rule.metadata.merge(
          'rule_label' => rule.rule_label,
          'rule_type' => rule.rule_type,
          'references' => rule.references,
        ),
      )
    end

    def connect_rule_to_declarables(rule_node, declarables, resolution_reason)
      declarable_nodes = upsert_and_fetch_declarable_nodes(declarables)
      NodeRepository.bulk_upsert_edges(rule_node, declarable_nodes, Edge::APPLIES_TO, 'resolution_reason' => resolution_reason)
    end

    def connect_rule_to_references(rule_node, declarables, rule)
      relationship = relationship_for(rule.rule_type)
      declarable_nodes = upsert_and_fetch_declarable_nodes(declarables)

      NodeRepository.bulk_upsert_edges(rule_node, declarable_nodes, relationship, 'rule_type' => rule.rule_type)
    end

    def upsert_and_fetch_declarable_nodes(declarables)
      declarables = declarables.uniq(&:goods_nomenclature_sid)
      return [] if declarables.empty?

      NodeRepository.bulk_upsert_goods_nomenclatures(declarables)
      Node.goods_nomenclatures
          .where(goods_nomenclature_sid: declarables.map(&:goods_nomenclature_sid))
          .all
    end

    def relationship_for(rule_type)
      case rule_type
      when 'excludes' then Edge::EXCLUDES
      when 'classifies_as' then Edge::CLASSIFIES_AS
      when 'classifies_only_as' then Edge::CLASSIFIES_ONLY_AS
      when 'subject_to' then Edge::SUBJECT_TO
      when 'defines_term' then Edge::DEFINES_TERM
      else Edge::CONSTRAINS
      end
    end

    def declarables_for_scope(scope_type, scope_id)
      TimeMachine.now do
        case scope_type
        when 'chapter'
          Chapter.actual.by_code(scope_id).all.flat_map { |chapter| declarables_below(chapter) }
        when 'section'
          section = Section[scope_id]
          section ? section.chapters.flat_map { |chapter| declarables_below(chapter) } : []
        else
          []
        end
      end
    end

    def declarables_for_reference(reference)
      TimeMachine.now do
        case reference[:type]
        when 'heading'
          Heading.actual.by_code(reference[:id]).all.flat_map { |heading| declarables_below(heading) }
        when 'chapter'
          Chapter.actual.by_code(reference[:id]).all.flat_map { |chapter| declarables_below(chapter) }
        when 'heading_range'
          heading_range(reference[:from], reference[:to]).flat_map do |heading_code|
            Heading.actual.by_code(heading_code).all.flat_map { |heading| declarables_below(heading) }
          end
        when 'chapter_range'
          chapter_range(reference[:from], reference[:to]).flat_map do |chapter_code|
            Chapter.actual.by_code(chapter_code).all.flat_map { |chapter| declarables_below(chapter) }
          end
        when 'section'
          declarables_for_section(reference[:id])
        when 'section_range'
          (reference[:from].to_i..reference[:to].to_i).flat_map { |section_id| declarables_for_section(section_id) }
        when 'goods_nomenclature_code'
          declarables_for_goods_nomenclature_code(reference[:id])
        when 'goods_nomenclature_code_range'
          goods_nomenclature_code_range(reference[:from], reference[:to]).flat_map do |code|
            declarables_for_goods_nomenclature_code(code)
          end
        else
          []
        end
      end
    end

    def heading_range(from, to)
      (from.to_i..to.to_i).map { |heading| heading.to_s.rjust(4, '0') }
    end

    def chapter_range(from, to)
      (from.to_i..to.to_i).map { |chapter| chapter.to_s.rjust(2, '0') }
    end

    def goods_nomenclature_code_range(from, to)
      return [] unless from.to_s.length == to.to_s.length

      from_int = from.to_i
      to_int = to.to_i
      return [] if to_int < from_int || (to_int - from_int) > 200

      (from_int..to_int).map { |code| code.to_s.rjust(from.length, '0') }
    end

    def declarables_for_section(section_id)
      section = Section[section_id]
      section ? section.chapters.flat_map { |chapter| declarables_below(chapter) } : []
    end

    def declarables_for_goods_nomenclature_code(code)
      GoodsNomenclature.actual
                       .where(Sequel.like(:goods_nomenclature_item_id, "#{code}%"))
                       .all
                       .flat_map { |goods_nomenclature| declarables_below(goods_nomenclature) }
    end

    def declarables_below(goods_nomenclature)
      ([goods_nomenclature] + goods_nomenclature.descendants)
        .select(&:declarable?)
        .uniq(&:goods_nomenclature_sid)
    end

    def clean_content(content)
      content.to_s
             .gsub(%r{\[([^\]]+)\]\([^)]+\)}, '\1')
             .squish
    end

    def rule_metadata(rule)
      {
        'rule_label' => rule.rule_label,
        'rule_type' => rule.rule_type,
      }
    end
  end
end
