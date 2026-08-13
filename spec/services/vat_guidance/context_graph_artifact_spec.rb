require 'digest'

RSpec.describe 'VAT guidance context graph artifact' do
  subject(:graph) do
    artifact_path = File.expand_path('../../../data/vat_guidance/context_graph.json', __dir__)
    JSON.parse(File.read(artifact_path))
  end

  let(:node_ids) { graph.fetch('nodes').pluck('id').to_set }

  it 'has a valid digest and unique graph identities' do
    content = graph.except('content_sha256')
    digest = Digest::SHA256.hexdigest(JSON.generate(deep_sort(content)))

    expect(graph.fetch('content_sha256')).to eq(digest)
    expect(graph.fetch('nodes').pluck('id')).to eq(graph.fetch('nodes').pluck('id').uniq)
    expect(graph.fetch('edges').pluck('id')).to eq(graph.fetch('edges').pluck('id').uniq)
  end

  it 'contains the four roots and sections directly referenced by them' do
    expect(graph.fetch('root_document_ids')).to contain_exactly(
      'document:/guidance/protective-equipment-and-vat-notice-70123',
      'document:/guidance/food-products-and-vat-notice-70114',
      'document:/guidance/catering-takeaway-food-and-vat-notice-7091',
      'document:/guidance/ships-aircraft-and-associated-services-notice-744c',
    )
    expect(graph.dig('summary', 'documents_captured')).to be > graph.fetch('root_document_ids').length
    expect(graph.fetch('documents')).to include(
      include('canonical_path' => '/guidance/vat-guide-notice-700'),
      include('canonical_path' => '/hmrc-internal-manuals/vat-supply-and-consideration'),
    )
    expect(graph.fetch('nodes')).to include(
      include('document_id' => 'document:/guidance/vat-guide-notice-700', 'node_type' => 'section'),
    )
  end

  it 'has valid edge endpoints and resolved commodity evidence' do
    expect(graph.fetch('edges')).to all(satisfy do |edge|
      node_ids.include?(edge.fetch('source_id')) &&
        (edge.fetch('resolution') == 'unresolved' || node_ids.include?(edge.fetch('target_id')))
    end)
    expect(graph.fetch('commodity_node_ids')).to contain_exactly(
      'commodity:2005202000',
      'commodity:2008939120',
      'commodity:2008979890',
      'commodity:8407100010',
      'commodity:8409100090',
      'commodity:8424100011',
    )
    graph.fetch('commodity_node_ids').each do |commodity_id|
      evidence = graph.fetch('edges').select do |edge|
        edge['source_id'] == commodity_id && edge['reference_kind'] == 'guidance_evidence'
      end

      expect(evidence).not_to be_empty
      expect(evidence).to all(include('resolution' => 'resolved'))
    end
  end

  it 'does not mark uncaptured external targets as resolved content' do
    external_node_ids = graph.fetch('nodes').filter_map { |node|
      node.fetch('id') if node['node_type'] == 'external_reference'
    }.to_set
    external_edges = graph.fetch('edges').select { |edge| external_node_ids.include?(edge.fetch('target_id')) }

    expect(external_edges).not_to be_empty
    expect(external_edges).to all(include('resolution' => 'unresolved'))
  end

  it 'does not mark uncaptured notice sections as resolved content' do
    notice_reference_ids = graph.fetch('nodes').filter_map { |node|
      node.fetch('id') if node['node_type'] == 'notice_reference'
    }.to_set
    notice_reference_edges = graph.fetch('edges').select do |edge|
      notice_reference_ids.include?(edge.fetch('target_id'))
    end

    expect(notice_reference_edges).not_to be_empty
    expect(notice_reference_edges).to all(include('resolution' => 'unresolved'))
  end

  it 'classifies root-document legislation separately from broken notice sections' do
    root_statutory_references = graph.fetch('edges').select do |edge|
      edge['reference_kind'] == 'statutory_reference' &&
        graph.fetch('root_document_ids').any? { |root_id| edge.fetch('source_id').start_with?(root_id) }
    end

    expect(root_statutory_references.pluck('reference_text')).to include(
      'section 30',
      'paragraph 94',
      'section 29A',
      'section 105(1)',
    )
    expect(root_statutory_references).to all(include('resolution' => 'resolved'))
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
end
