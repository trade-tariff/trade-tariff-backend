require 'digest'
require 'nokogiri'

module VatGuidance
  class ContextPacketAssembler
    SCHEMA_VERSION = 2
    MAX_CONTENT_CHARACTERS = 80_000
    TARGET_NOTICE_NUMBERS = %w[701/23 701/14 709/1].freeze
    COMPARISON_SECTION_ID =
      'document:/guidance/catering-takeaway-food-and-vat-notice-7091#information-in-this-notice'.freeze
    FOLLOWED_REFERENCE_KINDS = %w[
      hyperlink
      prose_section_reference
      prose_notice_reference
      prose_cross_document_reference
      statutory_reference
      guidance_evidence
    ].freeze

    def initialize(graph, comparison_section_id: COMPARISON_SECTION_ID, max_content_characters: MAX_CONTENT_CHARACTERS)
      @graph = graph.deep_stringify_keys
      @comparison_section_id = comparison_section_id
      @max_content_characters = max_content_characters
      @nodes_by_id = @graph.fetch('nodes').index_by { |node| node.fetch('id') }
      @documents_by_id = @graph.fetch('documents').index_by { |document| document.fetch('id') }
      @outgoing_edges = @graph.fetch('edges').group_by { |edge| edge.fetch('source_id') }
    end

    def call
      validate_graph!
      packets = source_sections.map { |section| assemble(section, include_references: true) }
      commodity_packets = source_commodities.map { |commodity| assemble(commodity, include_references: true) }
      comparison_source = @nodes_by_id.fetch(@comparison_section_id)

      artifact = {
        'schema_version' => SCHEMA_VERSION,
        'source_graph_sha256' => @graph.fetch('content_sha256'),
        'target_notice_numbers' => TARGET_NOTICE_NUMBERS,
        'traversal_policy' => traversal_policy,
        'packets' => packets,
        'commodity_packets' => commodity_packets,
        'comparisons' => [
          {
            'source_node_id' => comparison_source.fetch('id'),
            'purpose' => 'Measure what direct cross-notice context adds for a catering section.',
            'local_only' => assemble(comparison_source, include_references: false),
            'reference_expanded' => packets.find do |packet|
              packet.fetch('source').fetch('node_id') == comparison_source.fetch('id')
            end,
          },
        ],
        'summary' => summary(packets, commodity_packets),
      }
      artifact['content_sha256'] = sha256(canonical_json(artifact))
      artifact
    end

  private

    def validate_graph!
      missing_notices = TARGET_NOTICE_NUMBERS - target_documents.pluck('notice_number')
      raise ArgumentError, "Context graph is missing required notices: #{missing_notices.join(', ')}" if missing_notices.any?
      return if @nodes_by_id.key?(@comparison_section_id)

      raise ArgumentError, "Comparison section is missing: #{@comparison_section_id}"
    end

    def target_documents
      @target_documents ||= @graph.fetch('documents').select do |document|
        TARGET_NOTICE_NUMBERS.include?(document['notice_number'])
      end
    end

    def source_sections
      document_ids = target_documents.pluck('id').to_set
      @graph.fetch('nodes').select { |node|
        node['node_type'] == 'section' && document_ids.include?(node['document_id'])
      }.sort_by { |node| node.fetch('id') }
    end

    def source_commodities
      commodity_ids = @graph.fetch('commodity_node_ids', []).to_set
      @graph.fetch('nodes').select { |node|
        node['node_type'] == 'commodity' && commodity_ids.include?(node['id'])
      }.sort_by { |node| node.fetch('id') }
    end

    def assemble(source, include_references:)
      edges = include_references ? followed_edges(source) : []
      references = edges.map { |edge| reference(edge) }
      empty_references, references = references.partition { |item| item.fetch('content').empty? }
      candidates = source_content(source) + references.flat_map { |item| item.fetch('content') }
      included_nodes, omissions = apply_content_budget(candidates)
      included_node_ids = included_nodes.pluck('node_id').to_set
      references.each do |item|
        expanded_node_ids = item.fetch('content').pluck('node_id') & included_node_ids.to_a
        item['expanded_node_ids'] = expanded_node_ids
        item['omitted_node_ids'] = item.fetch('content').pluck('node_id') - expanded_node_ids
      end
      empty_reference_findings = empty_references.map do |item|
        item.except('content', 'expanded_node_ids').merge(
          'resolution_issue' => 'resolved_target_has_no_expandable_content',
        )
      end

      packet = {
        'packet_id' => packet_id(source.fetch('id'), include_references: include_references),
        'variant' => include_references ? 'reference_expanded' : 'local_only',
        'source' => anchor_for(source),
        'content' => included_nodes,
        'references' => references.map { |item| item.except('content') },
        'unresolved_references' => unresolved_references(source) + empty_reference_findings,
        'context_budget' => {
          'maximum_content_characters' => @max_content_characters,
          'included_content_characters' => included_nodes.sum { |node| node.fetch('text').length },
          'unit' => 'characters',
        },
        'omissions' => omissions,
      }
      packet['content_sha256'] = sha256(canonical_json(packet))
      packet
    end

    def followed_edges(source)
      @outgoing_edges.fetch(source.fetch('id'), []).select { |edge|
        edge['resolution'] == 'resolved' && FOLLOWED_REFERENCE_KINDS.include?(edge['reference_kind'])
      }.sort_by { |edge| [edge.fetch('reference_kind'), edge.fetch('target_id'), edge.fetch('id')] }
    end

    def unresolved_references(source)
      unresolved = @outgoing_edges.fetch(source.fetch('id'), []).select do |edge|
        edge['resolution'] == 'unresolved'
      end
      references = unresolved.map do |edge|
        edge.slice('target_id', 'reference_kind', 'reference_text', 'href', 'cross_document')
      end
      references.sort_by { |edge| [edge.fetch('reference_kind'), edge.fetch('target_id')] }
    end

    def reference(edge)
      target = @nodes_by_id.fetch(edge.fetch('target_id'))
      content = if target['node_type'] == 'document'
                  document_sections(target.fetch('id')).map { |node| content_node(node, role: 'referenced') }
                else
                  expandable_section_nodes(target).map { |node| content_node(node, role: 'referenced') }
                end

      edge.slice('target_id', 'reference_kind', 'reference_text', 'href', 'cross_document').merge(
        'expanded_node_ids' => content.pluck('node_id'),
        'content' => content,
      )
    end

    def document_sections(document_id)
      @graph.fetch('nodes').select { |node|
        node['node_type'] == 'section' && node['document_id'] == document_id
      }.sort_by { |node| node.fetch('id') }
    end

    def content_node(node, role:)
      {
        'role' => role,
        'node_id' => node.fetch('id'),
        'document_id' => node.fetch('document_id'),
        'guide_key' => node['guide_key'],
        'section_key' => node['section_key'],
        'heading' => node['heading'],
        'source_url' => node['source_url'],
        'text' => readable_text(node),
        'content_sha256' => node['content_sha256'],
        'node_type' => node['node_type'],
        'parent_id' => node['parent_id'],
        'chapter' => node['chapter'],
        'commodity_code' => node['commodity_code'],
      }
    end

    def readable_text(node)
      html = node['content_html']
      return node['heading'].to_s if html.blank?

      render_html(Nokogiri::HTML.fragment(html)).strip
    end

    def render_html(node)
      case node.name
      when 'text'
        node.text.gsub(/\s+/, ' ')
      when 'table'
        render_table(node)
      when 'ul', 'ol'
        render_list(node)
      when 'li'
        node.children.map { |child| render_html(child) }.join.strip
      when 'p', 'div', 'section', 'article', 'blockquote'
        "#{node.children.map { |child| render_html(child) }.join.strip}\n\n"
      when 'h1', 'h2', 'h3', 'h4', 'h5', 'h6'
        "#{'#' * node.name.delete_prefix('h').to_i} #{node.text.squish}\n\n"
      when 'br'
        "\n"
      else
        node.children.map { |child| render_html(child) }.join
      end
    end

    def render_table(table)
      rows = table.css('tr').map { |row|
        row.xpath('./th|./td').map { |cell| escape_markdown_table_cell(cell.text.squish) }
      }.reject(&:empty?)
      return '' if rows.empty?

      width = rows.map(&:length).max
      rows.map! { |row| row.fill('', row.length...width) }
      header = rows.shift
      lines = [header, Array.new(width, '---'), *rows]
      "#{lines.map { |row| "| #{row.join(' | ')} |" }.join("\n")}\n\n"
    end

    def escape_markdown_table_cell(text)
      text.each_char.map { |character| %w[\\ |].include?(character) ? "\\#{character}" : character }.join
    end

    def render_list(list)
      items = list.xpath('./li').map.with_index do |item, index|
        marker = list.name == 'ol' ? "#{index + 1}." : '-'
        "#{marker} #{render_html(item)}"
      end
      "#{items.join("\n")}\n\n"
    end

    def source_content(source)
      expandable_section_nodes(source).map { |node| content_node(node, role: 'source') }
    end

    def expandable_section_nodes(section)
      return [section] if section['content_html'].present?

      [section, *descendant_sections(section.fetch('id'))]
    end

    def descendant_sections(parent_id)
      children = @graph.fetch('nodes').select { |node|
        node['node_type'] == 'section' && node['parent_id'] == parent_id
      }.sort_by { |node| node.fetch('id') }
      children.flat_map { |child| [child, *descendant_sections(child.fetch('id'))] }
    end

    def apply_content_budget(candidates)
      remaining = @max_content_characters
      included = []
      omissions = []
      candidates.uniq { |node| node.fetch('node_id') }.each_with_index do |node, index|
        length = node.fetch('text').length
        if index.zero? || length <= remaining
          included << node
          remaining -= length
        else
          omissions << {
            'node_id' => node.fetch('node_id'),
            'document_id' => node.fetch('document_id'),
            'reason' => 'content_character_budget_exceeded',
            'content_characters' => length,
          }
        end
      end
      [included, omissions]
    end

    def anchor_for(node)
      node.slice(
        'node_type', 'guide_key', 'section_key', 'source_url', 'parent_id', 'chapter', 'commodity_code'
      ).merge(
        'node_id' => node.fetch('id'),
        'document_id' => node.fetch('document_id'),
        'heading' => node.fetch('heading'),
      )
    end

    def traversal_policy
      {
        'maximum_reference_depth' => 1,
        'followed_reference_kinds' => FOLLOWED_REFERENCE_KINDS,
        'resolved_references_only' => true,
        'document_target_expansion' => 'all anchored sections in the referenced document',
        'maximum_content_characters' => @max_content_characters,
        'budget_strategy' => 'Always include the source node, then include direct referenced nodes in deterministic order while they fit; record skipped nodes in omissions.',
        'transitive_references' => false,
        'rationale' => 'Direct references supply the context explicitly requested by a section; stopping after one hop bounds packet size and prevents unrelated reference chains from dominating the source text.',
      }
    end

    def summary(packets, commodity_packets)
      {
        'packets' => packets.length,
        'sections_by_notice' => TARGET_NOTICE_NUMBERS.index_with do |notice_number|
          guide_key = target_documents.find { |document| document['notice_number'] == notice_number }.fetch('guide_key')
          packets.count { |packet| packet.dig('source', 'guide_key') == guide_key }
        end,
        'packets_with_referenced_content' => packets.count { |packet| packet.fetch('content').length > 1 },
        'packets_with_unresolved_references' => packets.count { |packet| packet.fetch('unresolved_references').any? },
        'commodity_packets' => commodity_packets.length,
        'commodities_by_chapter' => commodity_packets.group_by { |packet| packet.dig('source', 'chapter') }
          .transform_values(&:length),
        'commodity_evidence_references' => commodity_packets.sum { |packet| packet.fetch('references').length },
      }
    end

    def packet_id(source_id, include_references:)
      variant = include_references ? 'reference-expanded' : 'local-only'
      "context-packet:#{sha256("#{source_id}:#{variant}")}"
    end

    def canonical_json(value)
      JSON.generate(deep_sort(value))
    end

    def deep_sort(value)
      case value
      when Hash then value.keys.sort.index_with { |key| deep_sort(value.fetch(key)) }
      when Array then value.map { |item| deep_sort(item) }
      else value
      end
    end

    def sha256(value)
      Digest::SHA256.hexdigest(value)
    end
  end
end
