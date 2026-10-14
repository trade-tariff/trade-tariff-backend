RSpec.describe Api::Admin::Csv::SearchReferenceChangeSerializer do
  subject(:rows) { CSV.parse(described_class.new([entry]).serialized_csv) }

  let(:entry) do
    SearchReferences::ChangeEntry.new(
      version_id: 7,
      search_reference_id: '42',
      section: :superseded,
      changed_at: Time.utc(2026, 10, 3, 9, 15),
      changed_by: 'ClearInvalidSearchReferences',
      goods_nomenclature_item_id: '0101210000',
      productline_suffix: '80',
      title: 'live horses',
      usage: SearchReference::FPO_USAGE,
      goods_nomenclature_url: 'https://example.com/commodities/0101210000',
      successor_ids: %w[0101999000 0101888000],
      previous_goods_nomenclature_item_id: nil,
      previous_title: nil,
      previous_usage: nil,
    )
  end

  it 'writes the header row' do
    expect(rows.first).to eq(
      [
        'Section',
        'Commodity code',
        'Product line suffix',
        'Title',
        'FPO only',
        'Commodity URL',
        'Successors',
        'Previous commodity code',
        'Previous title',
        'Previous usage',
        'Source',
        'Changed by',
        'Changed at',
        'Search reference ID',
        'Summary',
      ],
    )
  end

  it 'writes one row per change' do
    expect(rows.second).to eq(
      [
        'Superseded',
        '0101210000',
        '80',
        'live horses',
        'Yes',
        'https://example.com/commodities/0101210000',
        '0101999000 0101888000',
        nil,
        nil,
        nil,
        'Automatic clean-up',
        'ClearInvalidSearchReferences',
        '2026-10-03T09:15:00Z',
        '42',
        '0101210000 — live horses [FPO only] (https://example.com/commodities/0101210000) (successors: 0101999000, 0101888000)',
      ],
    )
  end

  context 'when untrusted text starts like a formula' do
    let(:entry) do
      SearchReferences::ChangeEntry.new(
        version_id: 7,
        search_reference_id: '42',
        section: :updated,
        changed_at: Time.utc(2026, 10, 3, 9, 15),
        changed_by: '=cmd|"/c calc"!A1',
        goods_nomenclature_item_id: nil,
        productline_suffix: '80',
        title: '=HYPERLINK("https://evil.example")',
        usage: SearchReference::SEARCH_USAGE,
        goods_nomenclature_url: nil,
        successor_ids: [],
        previous_goods_nomenclature_item_id: '0101210000',
        previous_title: '+SUM(1,2)',
        previous_usage: '@usage',
      )
    end

    let(:row) { rows.second.zip(rows.first).to_h { |value, header| [header, value] } }

    it 'escapes every text cell that could run as a formula', :aggregate_failures do
      expect(row['Title']).to eq(%('=HYPERLINK("https://evil.example")))
      expect(row['Previous title']).to eq("'+SUM(1,2)")
      expect(row['Previous usage']).to eq("'@usage")
      expect(row['Changed by']).to eq(%('=cmd|"/c calc"!A1))
      expect(row['Source']).to eq(%('=cmd|"/c calc"!A1))
    end

    it 'leaves other cells unchanged' do
      expect(row['Product line suffix']).to eq('80')
    end

    it 'never writes a cell that starts with a formula character' do
      expect(rows.second.compact).to all(satisfy { |cell| !cell.match?(Api::Shared::CsvSerializer::FORMULA_TRIGGER) })
    end
  end
end
