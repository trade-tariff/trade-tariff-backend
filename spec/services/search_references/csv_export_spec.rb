RSpec.describe SearchReferences::CsvExport do
  subject(:csv) { CSV.parse(described_class.call, headers: true) }

  let(:commodity) { create(:commodity, goods_nomenclature_item_id: '0101291000') }

  it 'includes the label and label state of the referenced commodity' do
    create(:search_reference, title: 'gift', referenced: commodity, usage: 'fpo')
    create(
      :goods_nomenclature_label,
      goods_nomenclature: commodity,
      description: 'Live horses',
      synonyms: Sequel.pg_array(%w[pony foal], :text),
      colloquial_terms: Sequel.pg_array(%w[nag], :text),
      known_brands: Sequel.pg_array(%w[Acme], :text),
      needs_review: true,
    )

    expect(csv.first.to_h).to include(
      'Title' => 'gift',
      'Usage' => 'fpo',
      'Label description' => 'Live horses',
      'Label synonyms' => 'pony; foal',
      'Label colloquial terms' => 'nag',
      'Label known brands' => 'Acme',
      'Label needs review' => 'true',
      'Label approved' => 'false',
    )
  end

  it 'leaves the label columns blank when the commodity has no label' do
    create(:search_reference, title: 'gift', referenced: commodity)

    expect(csv.first.to_h).to include('Label description' => nil, 'Label stale' => nil)
  end

  it 'includes references of every usage' do
    create(:search_reference, title: 'a', usage: 'search')
    create(:search_reference, title: 'b', usage: 'fpo')

    expect(csv.pluck('Usage')).to contain_exactly('search', 'fpo')
  end

  it 'escapes titles that spreadsheets could run as formulas' do
    create(:search_reference, title: '=cmd')

    expect(csv.first['Title']).to eq("'=cmd")
  end
end
