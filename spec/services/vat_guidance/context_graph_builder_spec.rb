RSpec.describe VatGuidance::ContextGraphBuilder do
  subject(:graph) { described_class.new([protective_equipment, food]).call }

  let(:protective_equipment) do
    content_payload(
      title: 'Protective equipment (VAT Notice 701/23)',
      path: '/guidance/protective-equipment-and-vat-notice-70123',
      body: <<~HTML,
        <div class="govspeak">
          <h2 id="overview">1. Overview</h2>
          <p>Read paragraphs 2.1 to 2.3.</p>
          <h2 id="boots">2. Boots</h2>
          <h3 id="qualifying-boots">2.1 Qualifying boots</h3>
          <p>Read section 2.3 and <a href="https://www.gov.uk/guidance/food-products-and-vat-notice-70114#liability">Food products (VAT Notice 701/14)</a>.</p>
          <h3 id="shoes">2.2 Shoes</h3>
          <h3 id="standards">2.3 Standards</h3>
          <p><a href="#missing-anchor">Withdrawn detail</a></p>
        </div>
      HTML
    )
  end

  let(:food) do
    content_payload(
      title: 'Food products (VAT Notice 701/14)',
      path: '/guidance/food-products-and-vat-notice-70114',
      body: <<~HTML,
        <div class="govspeak">
          <p>Temporary rate information.</p>
          <h2 id="liability">1. Liability</h2>
          <p><a href="https://www.gov.uk/hmrc-internal-manuals/vat-food/vfood1000">VAT Food manual</a></p>
        </div>
      HTML
    )
  end

  it 'captures document, preamble and heading nodes with stable section identity' do
    expect(graph.fetch('summary')).to include(
      'documents_captured' => 2,
      'sections_captured' => 7,
    )
    expect(graph.fetch('nodes')).to include(
      include(
        'id' => 'document:/guidance/protective-equipment-and-vat-notice-70123#qualifying-boots',
        'section_key' => 'qualifying-boots',
        'parent_id' => 'document:/guidance/protective-equipment-and-vat-notice-70123#boots',
      ),
      include(
        'id' => 'document:/guidance/food-products-and-vat-notice-70114#preamble',
        'content_html' => include('Temporary rate information'),
      ),
    )
  end

  it 'expands prose ranges and resolves links within and between notices' do
    edges = graph.fetch('edges')

    expect(edges).to include(
      include('target_id' => end_with('#qualifying-boots'), 'reference_kind' => 'prose_section_reference'),
      include('target_id' => end_with('#shoes'), 'reference_kind' => 'prose_section_reference'),
      include('target_id' => end_with('#standards'), 'reference_kind' => 'prose_section_reference'),
      include('target_id' => end_with('food-products-and-vat-notice-70114#liability'), 'cross_document' => true),
    )
  end

  it 'keeps external and unresolved references as findings' do
    expect(graph.fetch('nodes')).to include(
      include('node_type' => 'external_reference', 'source_url' => include('/hmrc-internal-manuals/')),
    )
    expect(graph.fetch('edges')).to include(
      include('target_id' => include('missing-anchor'), 'resolution' => 'unresolved'),
    )
    expect(graph.dig('summary', 'unresolved_references')).to eq(1)
  end

  it 'is deterministic and carries a digest of the complete graph' do
    rebuilt = described_class.new([protective_equipment, food]).call

    expect(rebuilt).to eq(graph)
    expect(graph.fetch('content_sha256')).to match(/\A[0-9a-f]{64}\z/)
  end

  def content_payload(title:, path:, body:)
    {
      'base_path' => path,
      'content_id' => SecureRandom.uuid,
      'title' => title,
      'description' => "Description of #{title}",
      'public_updated_at' => '2026-08-01T09:00:00Z',
      'details' => { 'body' => body },
    }
  end
end
