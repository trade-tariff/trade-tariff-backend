require 'digest'

RSpec.describe 'VAT guidance context packets artifact' do
  subject(:artifact) do
    JSON.parse(File.read(Rails.root.join('data/vat_guidance/context_packets.json')))
  end

  let(:graph) do
    JSON.parse(File.read(Rails.root.join('data/vat_guidance/context_graph.json')))
  end
  let(:target_documents) do
    graph.fetch('documents').select do |document|
      VatGuidance::ContextPacketAssembler::TARGET_NOTICE_NUMBERS.include?(document['notice_number'])
    end
  end
  let(:target_section_ids) do
    document_ids = target_documents.pluck('id').to_set
    graph.fetch('nodes').filter_map do |node|
      node.fetch('id') if node['node_type'] == 'section' && document_ids.include?(node['document_id'])
    end
  end

  it 'has exactly one expanded packet for every section of the three required notices' do
    packets = artifact.fetch('packets')

    expect(artifact.fetch('target_notice_numbers')).to eq(%w[701/23 701/14 709/1])
    expect(packets.length).to eq(141)
    expect(packets.pluck('variant').uniq).to eq(%w[reference_expanded])
    expect(packets.map { |packet| packet.dig('source', 'node_id') }).to match_array(target_section_ids)
    expect(artifact.dig('summary', 'sections_by_notice')).to eq(
      '701/23' => 31,
      '701/14' => 51,
      '709/1' => 59,
    )
  end

  it 'binds the artifact and every packet to deterministic content digests' do
    expect(artifact.fetch('source_graph_sha256')).to eq(graph.fetch('content_sha256'))
    expect(artifact.fetch('content_sha256')).to eq(digest(artifact.except('content_sha256')))
    expect(artifact.fetch('packets')).to all(satisfy do |packet|
      packet.fetch('content_sha256') == digest(packet.except('content_sha256'))
    end)
  end

  it 'preserves anchors and supplies every expanded reference target as readable content' do
    artifact.fetch('packets').each do |packet|
      source = packet.fetch('source')
      content = packet.fetch('content')

      expect(source).to include('node_id', 'document_id', 'guide_key', 'section_key', 'source_url')
      expect(content.first).to include(
        'node_id' => source.fetch('node_id'),
        'section_key' => source.fetch('section_key'),
        'role' => 'source',
      )
      expect(content).to all(include('node_id', 'document_id', 'section_key', 'source_url', 'text'))
      expect(packet.fetch('references').flat_map { |reference| reference.fetch('expanded_node_ids') })
        .to all(be_in(content.pluck('node_id')))
    end
  end

  it 'keeps local-only and cross-notice-expanded catering packets for comparison' do
    comparison = artifact.fetch('comparisons').sole
    local = comparison.fetch('local_only')
    expanded = comparison.fetch('reference_expanded')

    expect(comparison.fetch('source_node_id')).to eq(
      VatGuidance::ContextPacketAssembler::COMPARISON_SECTION_ID,
    )
    expect(local.fetch('content').length).to eq(1)
    expect(local.fetch('references')).to be_empty
    expect(expanded.fetch('content').length).to be > local.fetch('content').length
    expect(expanded.fetch('content')).to include(include('guide_key' => 'vat-notice-701-14', 'role' => 'referenced'))
  end

  def digest(value)
    Digest::SHA256.hexdigest(JSON.generate(deep_sort(value)))
  end

  def deep_sort(value)
    case value
    when Hash then value.keys.sort.index_with { |key| deep_sort(value.fetch(key)) }
    when Array then value.map { |item| deep_sort(item) }
    else value
    end
  end
end
