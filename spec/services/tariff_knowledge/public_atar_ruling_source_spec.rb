RSpec.describe TariffKnowledge::PublicAtarRulingSource do
  it 'loads public ATAR rulings from listing and detail pages' do
    stub_listing_page(1, refs: %w[600015846 600015845])
    stub_detail_page(
      '600015846',
      commodity_code: '4421910000',
      description: 'Cocktail umbrellas',
      keywords: ['COCKTAIL UMBRELLAS', 'OF WOOD'],
      justification: 'Classified in Chapter 44.',
    )
    stub_detail_page(
      '600015845',
      commodity_code: '2106909849',
      description: 'Fruit jelly',
      keywords: %w[FRUIT JELLY],
      justification: 'Classified in Chapter 21.',
    )

    rulings = described_class.call(limit: 2, max_pages: 1, request_delay: 0)

    expect(rulings).to contain_exactly(
      described_class::Ruling.new(
        ref: '600015846',
        commodity_code: '4421910000',
        goods_nomenclature_item_id: '4421910000',
        description: 'Cocktail umbrellas',
        keywords: ['COCKTAIL UMBRELLAS', 'OF WOOD'],
        justification: 'Classified in Chapter 44.',
        validity_start_date: Date.new(2026, 6, 26),
        validity_end_date: Date.new(2029, 6, 25),
        source_url: 'https://www.tax.service.gov.uk/search-for-advance-tariff-rulings/ruling/600015846',
        raw_fields: {
          'Start date' => '26 Jun 2026',
          'Expiry date' => '25 Jun 2029',
          'Commodity code' => '4421910000',
          'Description' => 'Cocktail umbrellas',
          'Keywords' => ['COCKTAIL UMBRELLAS', 'OF WOOD'],
          'Justification' => 'Classified in Chapter 44.',
        },
      ),
      described_class::Ruling.new(
        ref: '600015845',
        commodity_code: '2106909849',
        goods_nomenclature_item_id: '2106909849',
        description: 'Fruit jelly',
        keywords: %w[FRUIT JELLY],
        justification: 'Classified in Chapter 21.',
        validity_start_date: Date.new(2026, 6, 26),
        validity_end_date: Date.new(2029, 6, 25),
        source_url: 'https://www.tax.service.gov.uk/search-for-advance-tariff-rulings/ruling/600015845',
        raw_fields: {
          'Start date' => '26 Jun 2026',
          'Expiry date' => '25 Jun 2029',
          'Commodity code' => '2106909849',
          'Description' => 'Fruit jelly',
          'Keywords' => %w[FRUIT JELLY],
          'Justification' => 'Classified in Chapter 21.',
        },
      ),
    )
  end

  it 'scrapes listing pages until the public listing is exhausted when no limit is supplied' do
    stub_listing_page(1, refs: %w[600015846])
    stub_listing_page(2, refs: %w[600015845])
    stub_listing_page(3, refs: [])
    stub_detail_page('600015846', commodity_code: '4421910000', description: 'Cocktail umbrellas')
    stub_detail_page('600015845', commodity_code: '2106909849', description: 'Fruit jelly')

    rulings = described_class.call(max_pages: 10, request_delay: 0)

    expect(rulings.map(&:ref)).to eq(%w[600015846 600015845])
    expect(WebMock).to have_requested(:get, listing_url(3))
  end

  it 'retries politely when the public ATAR service returns a rate limit response' do
    stub_request(:get, listing_url(1))
      .to_return(status: 429, headers: { 'Retry-After' => '0' }, body: 'Too many requests')
      .then
      .to_return(status: 200, body: listing_html(%w[600015846]))
    stub_listing_page(2, refs: [])
    stub_detail_page('600015846', commodity_code: '4421910000', description: 'Cocktail umbrellas')

    rulings = described_class.call(max_pages: 2, request_delay: 0, max_retries: 1)

    expect(rulings.map(&:ref)).to eq(%w[600015846])
    expect(WebMock).to have_requested(:get, listing_url(1)).twice
  end

  it 'extracts subheading-level commodity codes when the ruling is not classified to 8 or 10 digits' do
    stub_detail_page('600010924', commodity_code: '630210', description: 'Mattress protector')

    ruling = described_class.new(request_delay: 0).ruling_for_ref('600010924')

    expect(ruling.commodity_code).to eq('630210')
    expect(ruling.goods_nomenclature_item_id).to eq('6302100000')
  end

  it 'raises an extraction error when a detail page has no commodity code' do
    stub_detail_page('600010924', commodity_code: 'not available', description: 'Mattress protector')

    expect {
      described_class.new(request_delay: 0).ruling_for_ref('600010924')
    }.to raise_error(TariffKnowledge::PublicAtarRulingSource::ExtractionError, /Commodity code/)
  end

  it 'raises an extraction error when a detail page has no validity start date' do
    stub_detail_page('600010924', commodity_code: '630210', description: 'Mattress protector', start_date: nil)

    expect {
      described_class.new(request_delay: 0).ruling_for_ref('600010924')
    }.to raise_error(TariffKnowledge::PublicAtarRulingSource::ExtractionError, /Start date/)
  end

  def stub_listing_page(page, refs:)
    stub_request(:get, listing_url(page))
      .with(headers: { 'User-Agent' => 'trade-tariff-backend-atar-import/1.0' })
      .to_return(status: 200, body: listing_html(refs))
  end

  def stub_detail_page(ref, commodity_code:, description:, keywords: %w[KEYWORD], justification: 'Classified by GIR 1.', start_date: '26 Jun 2026')
    stub_request(:get, "https://www.tax.service.gov.uk/search-for-advance-tariff-rulings/ruling/#{ref}")
      .with(headers: { 'User-Agent' => 'trade-tariff-backend-atar-import/1.0' })
      .to_return(
        status: 200,
        body: ruling_html(
          commodity_code:,
          description:,
          keywords:,
          justification:,
          start_date:,
        ),
      )
  end

  def listing_url(page)
    "https://www.tax.service.gov.uk/search-for-advance-tariff-rulings/search?page=#{page}"
  end

  def listing_html(refs)
    refs.map { |ref|
      %(<a href="/search-for-advance-tariff-rulings/ruling/#{ref}">View ruling #{ref}</a>)
    }.join("\n")
  end

  def ruling_html(commodity_code:, description:, keywords:, justification:, start_date:)
    keyword_items = keywords.map { |keyword|
      %(<li><span class="govuk-tag govuk-tag-atar govuk-tag--grey">#{keyword}</span></li>)
    }.join("\n")
    start_date_row =
      if start_date
        <<~HTML
          <div class="govuk-summary-list__row">
            <dt class="govuk-summary-list__key">Start date</dt>
            <dd class="govuk-summary-list__value">#{start_date}</dd>
          </div>
        HTML
      end

    <<~HTML
      <dl id="ruling-details" class="govuk-summary-list">
        #{start_date_row}
        <div class="govuk-summary-list__row">
          <dt class="govuk-summary-list__key">Expiry date</dt>
          <dd class="govuk-summary-list__value">25 Jun 2029</dd>
        </div>
        <div class="govuk-summary-list__row">
          <dt class="govuk-summary-list__key">Commodity code</dt>
          <dd class="govuk-summary-list__value"><span class="commodity-code">#{commodity_code}</span></dd>
        </div>
        <div class="govuk-summary-list__row">
          <dt class="govuk-summary-list__key">Description</dt>
          <dd class="govuk-summary-list__value">#{description}</dd>
        </div>
        <div class="govuk-summary-list__row">
          <dt class="govuk-summary-list__key">Keywords</dt>
          <dd class="govuk-summary-list__value"><ul id="keyword-list">#{keyword_items}</ul></dd>
        </div>
        <div class="govuk-summary-list__row">
          <dt class="govuk-summary-list__key">Justification</dt>
          <dd class="govuk-summary-list__value">#{justification}</dd>
        </div>
      </dl>
    HTML
  end
end
