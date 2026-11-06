RSpec.describe Api::Admin::Csv::SearchReferenceSerializer do
  subject(:csv) do
    CSV.parse(described_class.new(SearchReference.admin_export, { include_ai_labels: true }).serialized_csv, headers: true)
  end

  let(:commodity) { create(:commodity, goods_nomenclature_item_id: '0101291000') }

  it 'writes the headings in export order' do
    expect(csv.headers).to eq(
      [
        'Search reference ID',
        'Title',
        'Commodity code',
        'Product line suffix',
        'Referenced class',
        'Usage',
        'Label description',
        'Label synonyms',
        'Label colloquial terms',
        'Label known brands',
        'Label stale',
        'Label needs review',
        'Label approved',
        'Label manually edited',
        'Label expired',
      ],
    )
  end

  it 'includes the label and label state of the referenced commodity' do
    reference = create(:search_reference, title: 'gift', referenced: commodity, usage: 'fpo')
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
      'Search reference ID' => reference.id.to_s,
      'Title' => 'gift',
      'Commodity code' => '0101291000',
      'Referenced class' => 'Commodity',
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

  it 'omits AI-generated label columns by default' do
    create(:search_reference, title: 'gift', referenced: commodity)
    csv_without_ai_labels = CSV.parse(described_class.new(SearchReference.admin_export).serialized_csv, headers: true)

    expect(csv_without_ai_labels.headers).not_to include(
      'Label description',
      'Label synonyms',
      'Label colloquial terms',
      'Label known brands',
      'Label stale',
      'Label needs review',
      'Label approved',
      'Label manually edited',
      'Label expired',
    )
  end

  it 'includes references of every usage' do
    create(:search_reference, title: 'a', usage: 'search')
    create(:search_reference, title: 'b', usage: 'fpo')

    expect(csv.pluck('Usage')).to contain_exactly('search', 'fpo')
  end

  it 'escapes formula-like text in every CSV cell' do
    create(
      :search_reference,
      title: '=cmd',
      referenced: commodity,
    )
    create(
      :goods_nomenclature_label,
      goods_nomenclature: commodity,
      description: '=description',
      synonyms: Sequel.pg_array(['+synonym'], :text),
    )

    expect(csv.first['Title']).to eq("'=cmd")
    expect(csv.first['Label description']).to eq("'=description")
    expect(csv.first['Label synonyms']).to eq("'+synonym")
    expect(csv.first.fields.compact).to all(satisfy { |cell| !cell.match?(Api::Shared::CsvSerializer::FORMULA_TRIGGER) })
  end

  it 'reads referenced class from the selected column instead of the model method' do
    reference = SearchReference.new(referenced_class: 'Commodity')
    allow(reference).to receive(:referenced_class).and_raise('association loaded')

    rows = CSV.parse(described_class.new([reference]).serialized_csv, headers: true)

    expect(rows.first['Referenced class']).to eq('Commodity')
  end
end
