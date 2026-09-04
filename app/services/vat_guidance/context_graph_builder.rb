require 'digest'
require 'nokogiri'
require 'uri'

module VatGuidance
  class ContextGraphBuilder
    SCHEMA_VERSION = 1
    HEADING_SELECTOR = (2..6).map { |level| "h#{level}" }.join(',').freeze
    SECTION_REFERENCE_PATTERN = %r{
      \b(?:paragraph|section)s?\s+
      ((?:\d+(?:\.\d+)*[A-Z]?(?:\(\d+\))*(?:\s*(?:,|and|or|to|-)\s*\d+(?:\.\d+)*[A-Z]?(?:\(\d+\))*)*))
    }ix
    NOTICE_NUMBER_PATTERN = /\b(?:(\d{3})\s*\/\s*(\d+[A-Z]?)|(?<=Notice\s)(\d{3}[A-Z]))\b/i
    BARE_NOTICE_NUMBER_PATTERN = /\bNotice\s+(\d{3})\b/i

    Section = Data.define(:node, :element, :number)

    def initialize(
      payloads,
      commodity_contexts: [],
      source_failures: {},
      path_aliases: {},
      root_paths: nil
    )
      @payloads = payloads.map(&:deep_stringify_keys)
      @commodity_contexts = commodity_contexts.map(&:deep_stringify_keys)
      @source_failures = source_failures.stringify_keys
      @path_aliases = path_aliases.stringify_keys
      @root_paths = root_paths || @payloads.map { |payload| payload.fetch('base_path') }
    end

    def call
      build_documents_and_sections
      build_reference_edges
      build_commodity_context
      finalise_edges

      graph = {
        'schema_version' => SCHEMA_VERSION,
        'root_document_ids' => @root_paths.filter_map { |path| @document_by_path[path]&.fetch('id') },
        'commodity_node_ids' => @commodity_contexts.map { |context| commodity_id(context.fetch('commodity_code')) },
        'documents' => @documents,
        'nodes' => (@nodes + @external_nodes.values).sort_by { |node| node.fetch('id') },
        'edges' => @edges.sort_by { |edge| edge.fetch('id') },
      }
      graph['summary'] = summary_for(graph)
      graph['content_sha256'] = sha256(canonical_json(graph))
      graph
    end

  private

    def build_documents_and_sections
      @documents = []
      @nodes = []
      @sections = []
      @document_by_path = {}
      @document_by_notice_number = {}
      @node_by_document_and_anchor = {}

      @payloads.each do |payload|
        document = document_from(payload)
        @documents << document
        @document_by_path[document.fetch('canonical_path')] = document
        @document_by_notice_number[document['notice_number']] = document if document['notice_number']
        add_document_node(document)
        add_section_nodes(document, payload.dig('details', 'body').to_s)
      end
      add_path_aliases
    end

    def add_path_aliases
      @path_aliases.each do |requested_path, canonical_path|
        @document_by_path[requested_path] = @document_by_path[canonical_path] if @document_by_path[canonical_path]
      end
    end

    def document_from(payload)
      canonical_path = payload.fetch('base_path')
      {
        'id' => document_id(canonical_path),
        'guide_key' => guide_key(payload.fetch('title')),
        'notice_number' => notice_number(payload.fetch('title')),
        'content_id' => payload['content_id'],
        'title' => payload.fetch('title'),
        'description' => payload['description'],
        'canonical_path' => canonical_path,
        'source_url' => absolute_govuk_url(canonical_path),
        'public_updated_at' => payload['public_updated_at'],
        'body_sha256' => sha256(payload.dig('details', 'body').to_s),
      }
    end

    def add_document_node(document)
      node = {
        'id' => document.fetch('id'),
        'node_type' => 'document',
        'document_id' => document.fetch('id'),
        'guide_key' => document.fetch('guide_key'),
        'section_key' => nil,
        'heading' => document.fetch('title'),
        'heading_level' => 1,
        'parent_id' => nil,
        'source_url' => document.fetch('source_url'),
        'content_html' => '',
        'content_sha256' => sha256(''),
      }
      @nodes << node
      @node_by_document_and_anchor[[document.fetch('id'), nil]] = node
    end

    def add_section_nodes(document, body)
      fragment = Nokogiri::HTML.fragment(body)
      container = fragment.at_css('.govspeak') || fragment
      headings = container.css(HEADING_SELECTOR)
      add_preamble_node(document, container, headings.first)

      parents = []
      headings.each do |heading|
        level = heading.name.delete_prefix('h').to_i
        parents.pop while parents.any? && parents.last.fetch('heading_level') >= level
        content_html = content_after(heading)
        anchor = unique_anchor(document.fetch('id'), heading['id'].presence || slug(heading.text))
        node = {
          'id' => "#{document.fetch('id')}##{anchor}",
          'node_type' => 'section',
          'document_id' => document.fetch('id'),
          'guide_key' => document.fetch('guide_key'),
          'section_key' => anchor,
          'heading' => normalise_text(heading.text),
          'heading_level' => level,
          'parent_id' => parents.last&.fetch('id', nil) || document.fetch('id'),
          'source_url' => "#{document.fetch('source_url')}##{anchor}",
          'content_html' => content_html,
          'content_sha256' => sha256(content_html),
        }
        add_section(
          document,
          node,
          Nokogiri::HTML.fragment(content_html),
          heading_number(heading.text),
        )
        parents << node
      end
    end

    def add_preamble_node(document, container, first_heading)
      content = container.children.take_while { |child| child != first_heading }.map(&:to_html).join.strip
      return if normalise_text(Nokogiri::HTML.fragment(content).text).blank?

      node = {
        'id' => "#{document.fetch('id')}#preamble",
        'node_type' => 'section',
        'document_id' => document.fetch('id'),
        'guide_key' => document.fetch('guide_key'),
        'section_key' => 'preamble',
        'heading' => 'Preamble',
        'heading_level' => 2,
        'parent_id' => document.fetch('id'),
        'source_url' => document.fetch('source_url'),
        'content_html' => content,
        'content_sha256' => sha256(content),
      }
      add_section(document, node, Nokogiri::HTML.fragment(content), nil)
    end

    def add_section(document, node, element, number)
      @nodes << node
      @sections << Section.new(node:, element:, number:)
      @node_by_document_and_anchor[[document.fetch('id'), node.fetch('section_key')]] = node
    end

    def build_reference_edges
      @edges = []
      @external_nodes = {}
      @sections.each do |section|
        linked_section_numbers = section.element.css('a[href]').flat_map do |link|
          referenced_section_numbers(link.text)
        end
        linked_section_numbers = linked_section_numbers.to_set
        section.element.css('a[href]').each { |link| add_link_edge(section, link) }
        add_prose_edges(section, linked_section_numbers)
      end
    end

    def build_commodity_context
      add_chapter_nodes
      @commodity_contexts.each do |context|
        node = commodity_node(context)
        @nodes << node
        context.fetch('evidence').each { |evidence| add_evidence_edge(node, evidence) }
      end
    end

    def add_chapter_nodes
      @commodity_contexts.group_by { |context| context.fetch('chapter') }.each do |chapter, contexts|
        label = contexts.first.fetch('chapter_label')
        @nodes << {
          'id' => chapter_id(chapter),
          'node_type' => 'commodity_chapter',
          'document_id' => nil,
          'guide_key' => nil,
          'section_key' => nil,
          'heading' => "Chapter #{chapter} — #{label}",
          'heading_level' => nil,
          'parent_id' => nil,
          'source_url' => nil,
          'content_html' => nil,
          'content_sha256' => sha256("#{chapter}:#{label}"),
          'chapter' => chapter,
        }
      end
    end

    def commodity_node(context)
      code = context.fetch('commodity_code')
      {
        'id' => commodity_id(code),
        'node_type' => 'commodity',
        'document_id' => nil,
        'guide_key' => nil,
        'section_key' => nil,
        'heading' => context.fetch('label'),
        'heading_level' => nil,
        'parent_id' => chapter_id(context.fetch('chapter')),
        'source_url' => nil,
        'content_html' => nil,
        'content_sha256' => sha256(canonical_json(context.except('evidence'))),
        'chapter' => context.fetch('chapter'),
        'commodity_code' => code,
      }
    end

    def add_evidence_edge(source, evidence)
      target = @nodes.find do |node|
        node['node_type'] == 'section' &&
          node['guide_key'] == evidence.fetch('guide_key') &&
          node['section_key'] == evidence.fetch('section_key')
      end
      unless target
        raise "Unresolved commodity evidence #{evidence.fetch('guide_key')}##{evidence.fetch('section_key')} " \
              "for #{source.fetch('id')}"
      end

      add_edge(
        source,
        resolved_target(target),
        'guidance_evidence',
        "#{evidence.fetch('guide_key')}##{evidence.fetch('section_key')}",
        target.fetch('source_url'),
      )
    end

    def finalise_edges
      @edges = @edges.uniq { |edge| [edge['source_id'], edge['target_id'], edge['reference_kind'], edge['reference_text']] }
      @edges.each_with_index { |edge, index| edge['id'] = sprintf('reference-%04d', index + 1) }
    end

    def add_link_edge(section, link)
      href = link['href'].to_s.strip
      return if href.blank?

      target = resolve_link(section.node.fetch('document_id'), href, link.text)
      add_edge(section.node, target, 'hyperlink', normalise_text(link.text), href)
    end

    def add_prose_edges(section, linked_section_numbers)
      fragment = Nokogiri::HTML.fragment(section.node.fetch('content_html'))
      fragment.css('a').each { |link| link.replace(" #{link.text} ") }
      text = normalise_text(fragment.text)

      text.to_enum(:scan, SECTION_REFERENCE_PATTERN).each do
        match = Regexp.last_match
        expression = match[1]

        if statutory_reference?(text, match)
          add_statutory_edge(section, text, match)
          next
        end

        referenced_notice = referenced_notice_number(text, match)
        if referenced_notice
          add_notice_reference_edges(section, expression, referenced_notice)
          next
        end

        expand_section_numbers(expression, section.node.fetch('document_id')).each do |number|
          next if linked_section_numbers.include?(number)

          target = resolve_section_number(section.node.fetch('document_id'), number)
          reference_text = "section #{number}"

          add_edge(section.node, target, 'prose_section_reference', reference_text, nil)
        end
      end
    end

    def statutory_reference?(text, match)
      preceding_text = text[[match.begin(0) - 240, 0].max...match.begin(0)]
      following_text = text[match.end(0)...[match.end(0) + 180, text.length].min]

      preceding_text.match?(/\b(?:Act|Regulations?|Order)(?:\s+\d{4})?\s+\z/i) ||
        preceding_text.match?(/\b(?:Act|Regulations?|Order)(?:\s+\d{4})?\s*[:,]\s*.{0,220}\z/i) ||
        following_text.match?(/\A\s+of\b.{0,140}\b(?:Act|Regulations?|Order)(?:\s+\d{4})?\b/i)
    end

    def add_statutory_edge(section, text, match)
      citation = sentence_containing(text, match.begin(0), match.end(0))
      id = "statutory-reference:#{sha256(citation)}"
      @external_nodes[id] ||= {
        'id' => id,
        'node_type' => 'statutory_reference',
        'document_id' => id,
        'guide_key' => nil,
        'section_key' => nil,
        'heading' => citation,
        'heading_level' => nil,
        'parent_id' => nil,
        'source_url' => nil,
        'content_html' => nil,
        'content_sha256' => sha256(citation),
      }
      add_edge(
        section.node,
        resolved_target(@external_nodes.fetch(id)),
        'statutory_reference',
        normalise_text(match[0]),
        nil,
      )
    end

    def sentence_containing(text, start_index, end_index)
      sentence_start = start_index.zero? ? 0 : (text.rindex(/[.!?]/, start_index - 1)&.next || 0)
      sentence_end = text.index(/[.!?]/, end_index) || text.length
      normalise_text(text[sentence_start...sentence_end])
    end

    def referenced_notice_number(text, match)
      sentence = sentence_containing(text, match.begin(0), match.end(0))
      preceding_text = text[[match.begin(0) - 120, 0].max...match.begin(0)]
      preceding_citation = preceding_text.match(
        /(?:VAT\s+)?Notice\s+(?:\d{3}\s*\/\s*\d+[A-Z]?|\d{3}[A-Z])\s*,?\s*\z/i,
      )
      preceding_notice = notice_number(preceding_citation[0]) if preceding_citation
      return preceding_notice if preceding_notice

      following_text = text[match.end(0)...[match.end(0) + 180, text.length].min]
      following_notice = notice_number(following_text) if following_text.match?(/\A\s+of\b/i)
      return following_notice if following_notice

      notice_numbers = text.scan(BARE_NOTICE_NUMBER_PATTERN).flatten.uniq
      notice_numbers.first if sentence.match?(/\bVAT guide\b/i) && notice_numbers.one?
    end

    def add_notice_reference_edges(section, expression, notice)
      target_document = @document_by_notice_number[notice]
      if target_document
        expand_section_numbers(expression, target_document.fetch('id')).each do |number|
          add_edge(
            section.node,
            resolve_section_number(target_document.fetch('id'), number),
            'prose_cross_document_reference',
            "VAT Notice #{notice}, section #{number}",
            nil,
          )
        end
      else
        add_notice_reference_edge(section, expression, notice)
      end
    end

    def add_notice_reference_edge(section, expression, notice)
      reference = "VAT Notice #{notice}, section #{expression}"
      id = "notice-reference:#{notice.downcase}##{slug(expression)}"
      @external_nodes[id] ||= {
        'id' => id,
        'node_type' => 'notice_reference',
        'document_id' => id,
        'guide_key' => "vat-notice-#{notice.tr('/', '-').downcase}",
        'section_key' => expression,
        'heading' => reference,
        'heading_level' => nil,
        'parent_id' => nil,
        'source_url' => nil,
        'content_html' => nil,
        'content_sha256' => sha256(reference),
      }
      add_edge(
        section.node,
        { node: @external_nodes.fetch(id), resolution: 'unresolved' },
        'prose_notice_reference',
        reference,
        nil,
      )
    end

    def resolve_link(source_document_id, href, label)
      uri = URI.parse(href)
      path = uri.path.presence
      fragment = uri.fragment.presence
      target_document = if href.start_with?('#')
                          document_by_id(source_document_id)
                        else
                          @document_by_path[path] || @document_by_notice_number[notice_number(label)]
                        end

      if target_document
        target_node = @node_by_document_and_anchor[[target_document.fetch('id'), fragment]]
        return resolved_target(target_node) if target_node
        return unresolved_target("#{target_document.fetch('id')}##{fragment}", document_id: target_document.fetch('id')) if fragment

        return resolved_target(@node_by_document_and_anchor.fetch([target_document.fetch('id'), nil]))
      end

      external_target(href, label)
    rescue URI::InvalidURIError
      unresolved_target(href)
    end

    def resolve_section_number(document_id, number)
      section = @sections.find do |candidate|
        candidate.node.fetch('document_id') == document_id && candidate.number == number
      end
      section ? resolved_target(section.node) : unresolved_target("#{document_id}#section-#{number}", document_id:)
    end

    def resolved_target(node)
      { node:, resolution: 'resolved' }
    end

    def unresolved_target(identifier, document_id: nil)
      { node: nil, id: "unresolved:#{identifier}", document_id:, resolution: 'unresolved' }
    end

    def external_target(href, label)
      url = normalise_url(href)
      id = "external:#{url}"
      failure = @source_failures[URI.parse(url).path]
      node = {
        'id' => id,
        'node_type' => 'external_reference',
        'document_id' => id,
        'guide_key' => nil,
        'section_key' => URI.parse(url).fragment,
        'heading' => normalise_text(label),
        'heading_level' => nil,
        'parent_id' => nil,
        'source_url' => url,
        'content_html' => nil,
        'content_sha256' => nil,
      }
      node['fetch_error'] = failure if failure
      @external_nodes[id] ||= node
      {
        node: @external_nodes.fetch(id),
        resolution: 'unresolved',
      }
    end

    def add_edge(source, target, kind, text, href)
      target_id = target[:node]&.fetch('id') || target.fetch(:id)
      target_document_id = target[:node]&.fetch('document_id') || target[:document_id]
      @edges << {
        'id' => nil,
        'source_id' => source.fetch('id'),
        'target_id' => target_id,
        'reference_kind' => kind,
        'reference_text' => text,
        'href' => href,
        'resolution' => target.fetch(:resolution),
        'cross_document' => source['document_id'].present? && target_document_id.present? && target_document_id != source['document_id'],
      }
    end

    def summary_for(graph)
      edges = graph.fetch('edges')
      {
        'documents_captured' => graph.fetch('documents').length,
        'commodity_chapters_captured' => graph.fetch('nodes').count { |node| node['node_type'] == 'commodity_chapter' },
        'commodities_captured' => graph.fetch('nodes').count { |node| node['node_type'] == 'commodity' },
        'sections_captured' => graph.fetch('nodes').count { |node| node['node_type'] == 'section' },
        'reference_edges' => edges.length,
        'cross_document_edges' => edges.count { |edge| edge['cross_document'] },
        'unresolved_references' => edges.count { |edge| edge['resolution'] == 'unresolved' },
      }
    end

    def content_after(heading)
      content_nodes = heading.xpath('following-sibling::node()').take_while do |node|
        !node.element? || !node.name.match?(/\Ah[2-6]\z/)
      end
      content_nodes.map(&:to_html).join.strip
    end

    def expand_section_numbers(expression, document_id)
      numbers = referenced_section_numbers(expression)
      return numbers unless expression.match?(/\bto\b|-/) && numbers.length == 2

      available = @sections.filter_map do |section|
        section.number if section.node.fetch('document_id') == document_id
      end
      start_index = available.index(numbers.first)
      end_index = available.index(numbers.last)
      return numbers unless start_index && end_index && start_index <= end_index

      available[start_index..end_index]
    end

    def referenced_section_numbers(text)
      text.to_s.scan(/\d+(?:\.\d+)*[A-Z]?(?:\(\d+\))*/i).map(&:upcase)
    end

    def unique_anchor(document_id, requested_anchor)
      anchor = requested_anchor
      suffix = 2
      while @node_by_document_and_anchor.key?([document_id, anchor])
        anchor = "#{requested_anchor}-#{suffix}"
        suffix += 1
      end
      anchor
    end

    def document_by_id(id)
      @documents.find { |document| document.fetch('id') == id }
    end

    def document_id(canonical_path)
      "document:#{canonical_path}"
    end

    def chapter_id(chapter)
      "commodity-chapter:#{chapter}"
    end

    def commodity_id(code)
      "commodity:#{code}"
    end

    def guide_key(title)
      number = notice_number(title)
      number ? "vat-notice-#{number.tr('/', '-').downcase}" : slug(title)
    end

    def notice_number(text)
      match = text.to_s.match(NOTICE_NUMBER_PATTERN)
      return match[3]&.upcase || "#{match[1]}/#{match[2].upcase}" if match

      text.to_s.match(BARE_NOTICE_NUMBER_PATTERN)&.[](1)
    end

    def heading_number(text)
      text.to_s.match(/\A\s*(\d+(?:\.\d+)*[A-Z]?(?:\(\d+\))*)\b/i)&.[](1)&.upcase
    end

    def slug(text)
      text.to_s.parameterize
    end

    def normalise_url(href)
      uri = URI.parse(href)
      return URI.join('https://www.gov.uk', href).to_s if uri.host.nil? && href.start_with?('/')
      return href unless uri.is_a?(URI::HTTP)

      uri.scheme = 'https' if uri.host == 'www.gov.uk'
      uri.to_s
    end

    def absolute_govuk_url(path)
      "https://www.gov.uk#{path}"
    end

    def normalise_text(text)
      text.to_s.gsub(/\s+/, ' ').strip
    end

    def canonical_json(value)
      JSON.generate(deep_sort(value))
    end

    def deep_sort(value)
      case value
      when Hash
        value.keys.sort.index_with { |key| deep_sort(value.fetch(key)) }
      when Array
        value.map { |item| deep_sort(item) }
      else
        value
      end
    end

    def sha256(value)
      Digest::SHA256.hexdigest(value)
    end
  end
end
