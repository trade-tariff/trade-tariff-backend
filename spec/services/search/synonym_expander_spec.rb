RSpec.describe Search::SynonymExpander do
  let(:rules_path) { Rails.root.join('spec/fixtures/files/search_synonyms.txt') }

  it 'appends directional alternatives while preserving the original phrase' do
    query = 'Replacement HEPA filter unit'

    expect(described_class.call(query, rules_path:)).to eq('Replacement HEPA filter unit high efficiency particulate air filter')
  end

  it 'matches phrases case-insensitively' do
    query = 'replacement hepa FILTER'

    expect(described_class.call(query, rules_path:)).to eq('replacement hepa FILTER high efficiency particulate air filter')
  end

  it 'expands equivalent terms in either direction' do
    expect(described_class.call('TV stand', rules_path:)).to eq('TV stand television')
    expect(described_class.call('television stand', rules_path:)).to eq('television stand TV')
  end

  it 'matches only complete terms' do
    query = 'preHEPA filter unit'

    expect(described_class.call(query, rules_path:)).to eq(query)
  end

  it 'does not append an alternative already present in the query' do
    query = 'HEPA filter high efficiency particulate air filter'

    expect(described_class.call(query, rules_path:)).to eq(query)
  end

  it 'treats identity mappings as no-ops' do
    query = 'LED screen'

    expect(described_class.call(query, rules_path:)).to eq(query)
  end

  it 'rejects malformed directional rules with their line number' do
    invalid_rules_path = Rails.root.join('spec/fixtures/files/invalid_search_synonyms.txt')

    expect {
      described_class.call('HEPA filter', rules_path: invalid_rules_path)
    }.to raise_error(described_class::InvalidRule, /line 1/)
  end

  it 'loads the production rules file by default' do
    expect(described_class.call('replacement HEPA filter'))
      .to eq('replacement HEPA filter high efficiency particulate air filter')
  end
end
