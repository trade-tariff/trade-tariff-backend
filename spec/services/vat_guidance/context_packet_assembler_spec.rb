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

  it 'follows direct references only and records unresolved references' do
    packet = packet_for(source_id)

    expect(packet.fetch('content').pluck('node_id')).not_to include("#{notice_documents.first.fetch('id')}#section")
    expect(packet.fetch('unresolved_references')).to contain_exactly(
      include('target_id' => 'unresolved:/missing'),
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

  def node(id, document:, text:, node_type: 'section', section_key: nil)
    {
      'id' => id,
      'node_type' => node_type,
      'document_id' => document.fetch('id'),
      'guide_key' => document.fetch('guide_key'),
      'section_key' => section_key,
      'heading' => section_key || document.fetch('notice_number'),
      'source_url' => "https://www.gov.uk#{id.delete_prefix('document:')}",
      'content_html' => text && "<p>#{text}</p>",
      'content_sha256' => text && Digest::SHA256.hexdigest(text),
    }
  end

  def edge(id, source_id, target_id, resolution:)
    {
      'id' => id,
      'source_id' => source_id,
      'target_id' => target_id,
      'reference_kind' => 'hyperlink',
      'reference_text' => 'Reference',
      'href' => nil,
      'resolution' => resolution,
      'cross_document' => true,
    }
  end
end
