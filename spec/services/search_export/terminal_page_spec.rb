RSpec.describe SearchExport::TerminalPage do
  def item(code:, description:, confidence: nil, score: 1)
    { attributes: { goods_nomenclature_item_id: code, classification_description: description, confidence:, score: } }
  end

  def page(response)
    described_class.from_response(response)
  end

  it 'classifies an exact match as one result and keeps a known label' do
    result = page(data: [item(code: '0207141000', description: '<p>Frozen cuts</p>', confidence: 'strong', score: nil)])

    expect(result.end_page_type).to eq('Result')
    expect(result.results.map(&:description)).to eq(['Frozen cuts'])
    expect(result.results.map(&:confidence_label)).to eq(%w[Strong])
  end

  it 'captures rendered entities and line breaks as plain heading text' do
    result = page(data: [item(code: '0207141000', description: 'Cuts &amp; meat<br>frozen&nbsp;&lt;5 kg', score: nil)])

    expect(result.results.first.description).to eq('Cuts & meat frozen <5 kg')
  end

  it 'does not replace a missing card heading with another description' do
    result = page(data: [{ attributes: { goods_nomenclature_item_id: '0207141000', description: 'Other description', score: nil } }])

    expect(result.results.first.description).to eq('')
  end

  it 'leaves the exact-match label blank when the page showed no Strong, Good or Possible label' do
    result = page(data: [item(code: '0207141000', description: 'Frozen cuts', score: nil)])

    expect(result.results.map(&:confidence_label)).to eq([''])
  end

  it 'does not classify a pending question' do
    response = {
      data: [item(code: '0207141000', description: 'Frozen cuts')],
      meta: { interactive_search: { answers: [{ question: 'Bone in?', options: %w[Yes No], answer: nil }], result_limit: 0 } },
    }

    expect(page(response)).to be_nil
  end

  it 'classifies blocking guidance as an intercept without results' do
    response = {
      data: [],
      meta: { description_intercept: { excluded: true, message_header: 'Stop', message: 'Contact HMRC' } },
    }

    expect(page(response)).to have_attributes(end_page_type: 'Intercept', results: [])
  end

  it 'classifies an empty retrieval as no result' do
    expect(page(data: [])).to have_attributes(end_page_type: 'No result', results: [])
  end

  it 'classifies unknown confidence as no result and drops the codes' do
    response = {
      data: [item(code: '0207141000', description: 'Frozen cuts', confidence: 'unknown')],
      meta: { interactive_search: { answers: [{ question: 'Cut?', options: %w[Fillet], answer: 'Fillet' }], result_limit: 0 } },
    }

    expect(page(response)).to have_attributes(end_page_type: 'No result', results: [])
  end

  it 'orders shown results Strong, Good, Possible, then unlabelled' do
    response = {
      data: [
        item(code: '0207141002', description: 'Possible cut', confidence: 'possible'),
        item(code: '0207141000', description: 'Strong cut', confidence: 'strong'),
        item(code: '0207141001', description: 'Good cut', confidence: 'good'),
      ],
      meta: { interactive_search: { answers: [{ question: 'Cut?', options: %w[Fillet], answer: 'Fillet' }], result_limit: 0 } },
    }

    expect(page(response).results.map(&:confidence_label)).to eq(%w[Strong Good Possible])
  end
end
