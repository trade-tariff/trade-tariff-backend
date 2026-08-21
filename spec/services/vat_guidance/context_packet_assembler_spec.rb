RSpec.describe VatGuidance::ContextPacketAssembler do
  subject(:artifact) { described_class.new(graph, comparison_section_id: source_id).call }

  let(:notice_documents) do
    described_class::TARGET_NOTICE_NUMBERS.map.with_index do |notice, index|
      {
        'id' => "document:/notice-#{index}",
        'notice_number' => notice,
        'guide_key' => "guide-#{index}",
      }
    end
  end
  let(:source_id) { "#{notice_documents.last.fetch('id')}#information-in-this-notice" }
  let(:referenced_document) { notice_documents.second }
  let(:graph) do
    {
      'content_sha256' => 'a' * 64,
      'documents' => notice_documents,
      'nodes' => notice_documents.flat_map.with_index do |document, index|
        document_node = node(document.fetch('id'), document:, text: nil, node_type: 'document')
        section_key = index == 2 ? 'information-in-this-notice' : 'section'
        section = node("#{document.fetch('id')}##{section_key}", document:, text: "Text #{index}", section_key:)
        [document_node, section]
      end,
      'edges' => [
        edge('reference-1', source_id, referenced_document.fetch('id'), resolution: 'resolved'),
        edge('reference-2', "#{referenced_document.fetch('id')}#section", notice_documents.first.fetch('id'), resolution: 'resolved'),
        edge('reference-3', source_id, 'unresolved:/missing', resolution: 'unresolved'),
      ],
    }
  end

  it 'creates one expanded packet for every section of all three notices' do
    expect(artifact.fetch('packets').length).to eq(3)
    expect(artifact.dig('summary', 'sections_by_notice')).to eq(
      '701/23' => 1,
      '701/14' => 1,
      '709/1' => 1,
    )
  end

  it 'creates an anchored packet for each commodity with its guidance evidence' do
    commodity_id = 'commodity:2005202000'
    graph['commodity_node_ids'] = [commodity_id]
    graph.fetch('nodes') << {
      'id' => commodity_id,
      'node_type' => 'commodity',
      'document_id' => nil,
      'guide_key' => nil,
      'section_key' => nil,
      'parent_id' => 'commodity-chapter:20',
      'heading' => 'Packaged potato crisps',
      'source_url' => nil,
      'content_html' => nil,
      'content_sha256' => 'b' * 64,
      'chapter' => '20',
      'commodity_code' => '2005202000',
    }
    graph.fetch('edges') << edge(
      'evidence-1',
      commodity_id,
      "#{referenced_document.fetch('id')}#section",
      resolution: 'resolved',
      reference_kind: 'guidance_evidence',
    )

    packet = artifact.fetch('commodity_packets').sole

    expect(packet.fetch('source')).to include(
      'node_id' => commodity_id,
      'node_type' => 'commodity',
      'chapter' => '20',
      'commodity_code' => '2005202000',
    )
    expect(packet.fetch('references')).to contain_exactly(
      include('reference_kind' => 'guidance_evidence', 'expanded_node_ids' => ["#{referenced_document.fetch('id')}#section"]),
    )
    expect(packet.fetch('content')).to include(
      include('node_id' => commodity_id, 'role' => 'source'),
      include('node_id' => "#{referenced_document.fetch('id')}#section", 'role' => 'referenced'),
    )
  end

  it 'preserves source and referenced anchors in LLM-readable content' do
    packet = packet_for(source_id)

    expect(packet.fetch('source')).to include(
      'node_id' => source_id,
      'section_key' => 'information-in-this-notice',
    )
    expect(packet.fetch('content')).to include(
      include('node_id' => source_id, 'role' => 'source', 'text' => 'Text 2'),
      include(
        'node_id' => "#{referenced_document.fetch('id')}#section",
        'section_key' => 'section',
        'role' => 'referenced',
        'text' => 'Text 1',
      ),
    )
  end

  it 'preserves table columns and list items as Markdown' do
    source = graph.fetch('nodes').find { |item| item.fetch('id') == source_id }
    source['content_html'] = <<~HTML
      <table><tr><th>Food</th><th>VAT rate</th></tr><tr><td>Cold takeaway | C:\\menu</td><td>Zero-rated</td></tr></table>
      <ul><li>Check the product</li><li>Check how it is supplied</li></ul>
    HTML

    text = packet_for(source_id).fetch('content').first.fetch('text')

    expect(text).to include(
      "| Food | VAT rate |\n| --- | --- |\n| Cold takeaway \\| C:\\\\menu | Zero-rated |",
      "- Check the product\n- Check how it is supplied",
    )
  end

  it 'includes anchored descendants when a source section only contains a heading' do
    source = graph.fetch('nodes').find { |item| item.fetch('id') == source_id }
    source['content_html'] = ''
    descendant_id = "#{source_id}/detail"
    graph.fetch('nodes') << node(
      descendant_id,
      document: notice_documents.last,
      text: 'Substantive descendant text',
      section_key: 'detail',
      parent_id: source_id,
    )

    expect(packet_for(source_id).fetch('content')).to include(
      include('node_id' => source_id, 'text' => 'information-in-this-notice'),
      include('node_id' => descendant_id, 'section_key' => 'detail', 'text' => 'Substantive descendant text'),
    )
  end

  it 'follows direct references only and records unresolved references' do
    packet = packet_for(source_id)

    expect(packet.fetch('content').pluck('node_id')).not_to include("#{notice_documents.first.fetch('id')}#section")
    expect(packet.fetch('unresolved_references')).to contain_exactly(
      include('target_id' => 'unresolved:/missing'),
    )
  end

  it 'does not substitute an uncaptured external link label for referenced content' do
    external_id = 'external:https://example.test/legislation'
    graph.fetch('nodes') << {
      'id' => external_id,
      'node_type' => 'external_reference',
      'document_id' => external_id,
      'guide_key' => nil,
      'section_key' => nil,
      'parent_id' => nil,
      'heading' => 'Section 30 of the VAT Act 1994',
      'source_url' => 'https://example.test/legislation',
      'content_html' => nil,
      'content_sha256' => nil,
    }
    graph.fetch('edges') << edge('external-1', source_id, external_id, resolution: 'unresolved')

    packet = packet_for(source_id)

    expect(packet.fetch('content').pluck('node_id')).not_to include(external_id)
    expect(packet.fetch('unresolved_references')).to include(include('target_id' => external_id))
  end

  it 'records a resolved document with no expandable sections as unresolved' do
    graph.fetch('nodes').reject! do |item|
      item['node_type'] == 'section' && item['document_id'] == referenced_document.fetch('id')
    end

    packet = packet_for(source_id)

    expect(packet.fetch('references')).to be_empty
    expect(packet.fetch('unresolved_references')).to include(
      include(
        'target_id' => referenced_document.fetch('id'),
        'resolution_issue' => 'resolved_target_has_no_expandable_content',
      ),
    )
  end

  it 'bounds referenced content deterministically and records omitted nodes' do
    limited_artifact = described_class.new(
      graph,
      comparison_section_id: source_id,
      max_content_characters: 6,
    ).call
    packet = limited_artifact.fetch('packets').find { |item| item.dig('source', 'node_id') == source_id }

    expect(packet.dig('context_budget', 'maximum_content_characters')).to eq(6)
    expect(packet.fetch('content').pluck('node_id')).to eq([source_id])
    expect(packet.fetch('references').sole).to include(
      'expanded_node_ids' => [],
      'omitted_node_ids' => ["#{referenced_document.fetch('id')}#section"],
    )
    expect(packet.fetch('omissions')).to contain_exactly(
      include(
        'node_id' => "#{referenced_document.fetch('id')}#section",
        'reason' => 'content_character_budget_exceeded',
      ),
    )
  end

  it 'retains local-only and expanded versions of the catering packet' do
    comparison = artifact.fetch('comparisons').sole

    expect(comparison.fetch('source_node_id')).to eq(source_id)
    expect(comparison.dig('local_only', 'variant')).to eq('local_only')
    expect(comparison.dig('local_only', 'content').length).to eq(1)
    expect(comparison.dig('reference_expanded', 'variant')).to eq('reference_expanded')
    expect(comparison.dig('reference_expanded', 'content').length).to eq(2)
  end

  it 'is deterministic and binds packets to the graph digest' do
    rebuilt = described_class.new(graph, comparison_section_id: source_id).call

    expect(rebuilt).to eq(artifact)
    expect(artifact.fetch('source_graph_sha256')).to eq('a' * 64)
    expect(artifact.fetch('content_sha256')).to match(/\A[0-9a-f]{64}\z/)
    expect(artifact.fetch('packets')).to all(include('content_sha256' => match(/\A[0-9a-f]{64}\z/)))
  end

  def packet_for(source_node_id)
    artifact.fetch('packets').find { |packet| packet.dig('source', 'node_id') == source_node_id }
  end

  def node(id, document:, text:, node_type: 'section', section_key: nil, parent_id: nil)
    {
      'id' => id,
      'node_type' => node_type,
      'document_id' => document.fetch('id'),
      'guide_key' => document.fetch('guide_key'),
      'section_key' => section_key,
      'parent_id' => parent_id,
      'heading' => section_key || document.fetch('notice_number'),
      'source_url' => "https://www.gov.uk#{id.delete_prefix('document:')}",
      'content_html' => text && "<p>#{text}</p>",
      'content_sha256' => text && Digest::SHA256.hexdigest(text),
    }
  end

  def edge(id, source_id, target_id, resolution:, reference_kind: 'hyperlink')
    {
      'id' => id,
      'source_id' => source_id,
      'target_id' => target_id,
      'reference_kind' => reference_kind,
      'reference_text' => 'Reference',
      'href' => nil,
      'resolution' => resolution,
      'cross_document' => true,
    }
  end
end
