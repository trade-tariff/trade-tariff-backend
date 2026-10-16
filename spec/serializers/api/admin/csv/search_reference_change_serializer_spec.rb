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
        'Operation',
        'Commodity code',
        'Product line suffix',
        'Title',
        'Commodity URL',
        'Successors',
        'Previous commodity code',
        'Previous title',
        'Previous usage',
        'Changed by',
        'Changed at',
        'Search reference ID',
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
        'https://example.com/commodities/0101210000',
        '0101999000 0101888000',
        nil,
        nil,
        nil,
        'Automatic clean-up',
        '2026-10-03T09:15:00Z',
        '42',
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
    end

    it 'leaves other cells unchanged' do
      expect(row['Product line suffix']).to eq('80')
    end

    it 'never writes a cell that starts with a formula character' do
      expect(rows.second.compact).to all(satisfy { |cell| !cell.match?(Api::Shared::CsvSerializer::FORMULA_TRIGGER) })
    end
  end

  context 'when an admin user made the change' do
    let(:admin_uid) { '11111111-1111-4111-8111-111111111111' }
    let(:row) { rows.second.zip(rows.first).to_h { |value, header| [header, value] } }

    def entry_by(changed_by_name)
      SearchReferences::ChangeEntry.new(**entry.to_h, changed_by: admin_uid, changed_by_name:)
    end

    it 'shows the admin user name' do
      rows = CSV.parse(described_class.new([entry_by('Jane Smith')]).serialized_csv, headers: true)

      expect(rows.first['Changed by']).to eq('Jane Smith')
    end

    it 'shows "Admin user" when there is no name' do
      rows = CSV.parse(described_class.new([entry_by(nil)]).serialized_csv, headers: true)

      expect(rows.first['Changed by']).to eq('Admin user')
    end

    it 'escapes a name that starts like a formula' do
      rows = CSV.parse(described_class.new([entry_by('=1+1')]).serialized_csv, headers: true)

      expect(rows.first['Changed by']).to eq("'=1+1")
    end
  end
end
