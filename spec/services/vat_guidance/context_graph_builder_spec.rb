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
      include(
        'target_id' => start_with('external:'),
        'reference_kind' => 'hyperlink',
        'resolution' => 'unresolved',
      ),
      include('target_id' => include('missing-anchor'), 'resolution' => 'unresolved'),
    )
    expect(graph.dig('summary', 'unresolved_references')).to eq(2)
  end

  it 'classifies statutory citations without treating them as notice sections' do
    legislation = content_payload(
      title: 'Legislation references (VAT Notice 700/1)',
      path: '/guidance/legislation-references',
      body: <<~HTML,
        <div class="govspeak">
          <h2 id="law">1. Law</h2>
          <p>The VAT Act 1994, section 29A applies.</p>
          <p>Section 105(1) of the Civil Aviation Act 1982 also applies.</p>
        </div>
      HTML
    )
    legislation_graph = described_class.new([legislation]).call

    expect(legislation_graph.fetch('edges')).to include(
      include('reference_kind' => 'statutory_reference', 'reference_text' => 'section 29A'),
      include('reference_kind' => 'statutory_reference', 'reference_text' => 'Section 105(1)'),
    )
    expect(legislation_graph.fetch('edges')).not_to include(
      include('reference_kind' => 'prose_section_reference', 'target_id' => end_with('#section-29')),
      include('reference_kind' => 'prose_section_reference', 'target_id' => end_with('#section-105')),
    )
    expect(legislation_graph.dig('summary', 'unresolved_references')).to eq(0)
  end

  it 'captures a statutory citation at the start of a guidance section' do
    legislation = content_payload(
      title: 'Legislation references (VAT Notice 700/1)',
      path: '/guidance/legislation-references',
      body: <<~HTML,
        <div class="govspeak">
          <p>Section 105(1) of the Civil Aviation Act 1982 applies. Further guidance follows.</p>
        </div>
      HTML
    )
    legislation_graph = described_class.new([legislation]).call

    expect(legislation_graph.fetch('nodes')).to include(
      include(
        'node_type' => 'statutory_reference',
        'heading' => 'Section 105(1) of the Civil Aviation Act 1982 applies',
      ),
    )
  end

  it 'does not suppress statutory citations when unrelated links contain the same number' do
    legislation = content_payload(
      title: 'Legislation references (VAT Notice 700/1)',
      path: '/guidance/legislation-references',
      body: <<~HTML,
        <div class="govspeak">
          <h2 id="law">1. Law</h2>
          <p><a href="#footnote-105">Footnote 105(1)</a></p>
          <p>Section 105(1) of the Civil Aviation Act 1982 applies.</p>
        </div>
      HTML
    )
    legislation_graph = described_class.new([legislation]).call

    expect(legislation_graph.fetch('edges')).to include(
      include('reference_kind' => 'statutory_reference', 'reference_text' => 'Section 105(1)'),
    )
  end

  it 'does not suppress notice citations when unrelated links contain the same section number' do
    source_notice = content_payload(
      title: 'Source references (VAT Notice 700/1)',
      path: '/guidance/source-references',
      body: <<~HTML,
        <div class="govspeak">
          <h2 id="references">1. References</h2>
          <p><a href="#footnote-3">Footnote 3</a></p>
          <p>VAT Notice 701/14, section 3 applies.</p>
        </div>
      HTML
    )
    target_notice = content_payload(
      title: 'Target guidance (VAT Notice 701/14)',
      path: '/guidance/target-guidance',
      body: <<~HTML,
        <div class="govspeak">
          <h2 id="target-section">3. Target section</h2>
        </div>
      HTML
    )
    notice_graph = described_class.new([source_notice, target_notice]).call

    expect(notice_graph.fetch('edges')).to include(
      include(
        'target_id' => end_with('#target-section'),
        'reference_kind' => 'prose_cross_document_reference',
        'reference_text' => 'VAT Notice 701/14, section 3',
      ),
    )
  end

  it 'keeps a section reference local when an earlier sentence links to another notice' do
    source_notice = content_payload(
      title: 'Catering (VAT Notice 709/1)',
      path: '/guidance/catering',
      body: <<~HTML,
        <h2 id="vending">2.4 Vending machines</h2>
        <p>Read <a href="/guidance/food">Food products (VAT Notice 701/14)</a> and section 3.3 for evidence.</p>
        <p>Read section 5.5 on catering in student unions.</p>
        <h2 id="student-unions">5.5 Catering provided by student unions</h2>
        <p>Student union guidance.</p>
      HTML
    )
    food_notice = content_payload(
      title: 'Food products (VAT Notice 701/14)',
      path: '/guidance/food',
      body: '<h2 id="food">Food</h2><p>Food guidance.</p>',
    )

    local_graph = described_class.new([source_notice, food_notice]).call

    expect(local_graph.fetch('edges')).to include(
      include(
        'source_id' => 'document:/guidance/catering#vending',
        'target_id' => 'document:/guidance/catering#student-unions',
        'reference_kind' => 'prose_section_reference',
        'resolution' => 'resolved',
      ),
    )
  end

  it 'suppresses only the section numbers that are already hyperlinked' do
    partially_linked = content_payload(
      title: 'Partially linked sections (VAT Notice 700/1)',
      path: '/guidance/partially-linked-sections',
      body: <<~HTML,
        <div class="govspeak">
          <h2 id="summary">1. Summary</h2>
          <p>Read sections <a href="#twelve">12</a>, 13 and 14.</p>
          <h2 id="twelve">12. Twelve</h2>
          <h2 id="thirteen">13. Thirteen</h2>
          <h2 id="fourteen">14. Fourteen</h2>
        </div>
      HTML
    )
    partially_linked_graph = described_class.new([partially_linked]).call
    section_edges = partially_linked_graph.fetch('edges').select do |edge|
      edge.fetch('source_id').end_with?('#summary')
    end

    expect(section_edges).to include(
      include('target_id' => end_with('#twelve'), 'reference_kind' => 'hyperlink'),
      include('target_id' => end_with('#thirteen'), 'reference_kind' => 'prose_section_reference'),
      include('target_id' => end_with('#fourteen'), 'reference_kind' => 'prose_section_reference'),
    )
    expect(section_edges).not_to include(
      include('target_id' => end_with('#twelve'), 'reference_kind' => 'prose_section_reference'),
    )
  end

  it 'does not treat bare statutory-style numbers as VAT notice numbers' do
    payload = content_payload(
      title: 'Number references (VAT Notice 700/1)',
      path: '/guidance/number-references',
      body: <<~HTML,
        <div class="govspeak">
          <h2 id="summary">1. Summary</h2>
          <p>Regulation 105A applies. Read section 3.</p>
          <h2 id="details">3. Details</h2>
        </div>
      HTML
    )
    number_graph = described_class.new([payload]).call

    expect(number_graph.fetch('edges')).to include(
      include('target_id' => end_with('#details'), 'reference_kind' => 'prose_section_reference'),
    )
    expect(number_graph.fetch('nodes')).not_to include(include('node_type' => 'notice_reference'))
  end

  it 'resolves section numbers case-insensitively' do
    payload = content_payload(
      title: 'Lettered sections (VAT Notice 700/1)',
      path: '/guidance/lettered-sections',
      body: <<~HTML,
        <div class="govspeak">
          <h2 id="summary">1. Summary</h2>
          <p>Read section 29A.</p>
          <h2 id="lettered">29a. Lettered section</h2>
        </div>
      HTML
    )
    lettered_graph = described_class.new([payload]).call

    expect(lettered_graph.fetch('edges')).to include(
      include(
        'target_id' => end_with('#lettered'),
        'reference_kind' => 'prose_section_reference',
        'resolution' => 'resolved',
      ),
    )
  end

  it 'records official sources that could not be fetched as unresolved findings' do
    missing_path = '/guidance/withdrawn-vat-notice'
    payload = content_payload(
      title: 'Source notice (VAT Notice 700/1)',
      path: '/guidance/source-notice',
      body: %(<div class="govspeak"><h2 id="source">1. Source</h2><a href="#{missing_path}">Withdrawn</a></div>),
    )
    failed_graph = described_class.new(
      [payload],
      source_failures: { missing_path => 'HTTP 404' },
    ).call

    expect(failed_graph.fetch('nodes')).to include(
      include('source_url' => "https://www.gov.uk#{missing_path}", 'fetch_error' => 'HTTP 404'),
    )
    expect(failed_graph.fetch('edges')).to include(
      include('href' => missing_path, 'resolution' => 'unresolved'),
    )
  end

  it 'is deterministic and carries a digest of the complete graph' do
    rebuilt = described_class.new([protective_equipment, food]).call

    expect(rebuilt).to eq(graph)
    expect(graph.fetch('content_sha256')).to match(/\A[0-9a-f]{64}\z/)
  end

  it 'derives a stable guide key for a VAT notice without a slash' do
    aviation = content_payload(
      title: 'Ships, trains, aircraft and associated services (VAT Notice 744C)',
      path: '/guidance/ships-aircraft-and-associated-services-notice-744c',
      body: '<div class="govspeak"><h2 id="aircraft">3. Aircraft</h2></div>',
    )

    document = described_class.new([aviation]).call.fetch('documents').first

    expect(document).to include('guide_key' => 'vat-notice-744c', 'notice_number' => '744C')
  end

  it 'adds commodity chapters, commodity nodes and resolved guidance evidence edges' do
    commodity_context = {
      'chapter' => '20',
      'chapter_label' => 'Prepared food',
      'commodity_code' => '2005202000',
      'label' => 'Packaged potato crisps',
      'evidence' => [
        {
          'guide_key' => 'vat-notice-701-23',
          'section_key' => 'overview',
        },
      ],
    }
    commodity_graph = described_class.new(
      [protective_equipment],
      commodity_contexts: [commodity_context],
    ).call

    expect(commodity_graph.fetch('nodes')).to include(
      include(
        'id' => 'commodity-chapter:20',
        'node_type' => 'commodity_chapter',
        'heading' => 'Chapter 20 — Prepared food',
      ),
      include(
        'id' => 'commodity:2005202000',
        'node_type' => 'commodity',
        'parent_id' => 'commodity-chapter:20',
      ),
    )
    expect(commodity_graph.fetch('edges')).to include(
      include(
        'source_id' => 'commodity:2005202000',
        'target_id' => end_with('#overview'),
        'reference_kind' => 'guidance_evidence',
        'resolution' => 'resolved',
      ),
    )
    expect(commodity_graph.fetch('summary')).to include(
      'commodity_chapters_captured' => 1,
      'commodities_captured' => 1,
    )
  end

  it 'fails when curated commodity evidence does not resolve to a section' do
    commodity_context = {
      'chapter' => '20',
      'chapter_label' => 'Prepared food',
      'commodity_code' => '2005202000',
      'label' => 'Packaged potato crisps',
      'evidence' => [
        {
          'guide_key' => 'vat-notice-701-23',
          'section_key' => 'missing-section',
        },
      ],
    }

    expect {
      described_class.new([protective_equipment], commodity_contexts: [commodity_context]).call
    }.to raise_error(
      RuntimeError,
      'Unresolved commodity evidence vat-notice-701-23#missing-section for commodity:2005202000',
    )
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
