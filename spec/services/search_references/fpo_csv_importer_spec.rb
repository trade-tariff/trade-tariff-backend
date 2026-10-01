require 'csv'

RSpec.describe SearchReferences::FpoCsvImporter do
  subject(:import) { described_class.call(csv_file.path, output:) }

  let(:output) { StringIO.new }
  let(:rows) { [] }

  let(:csv_file) do
    Tempfile.new(%w[fpo_extra_references .csv]).tap do |file|
      file.write(CSV.generate { |csv| ([['Goods Description', 'Commodity Code']] + rows).each { |row| csv << row } })
      file.flush
    end
  end

  let!(:commodity) { create(:commodity, :actual, goods_nomenclature_item_id: '3402509000') }

  after { csv_file.close! }

  around { |example| TimeMachine.now { example.run } }

  context 'with valid 8 and 10 digit codes' do
    let(:rows) do
      [
        ['165ml Brush  Cleaner', '3402509000'],
        ['100 ariel pods', '34025090'],
      ]
    end

    it 'creates fpo references for each row' do
      expect { import }.to change { SearchReference.for_fpo.count }.by(2)
    end

    it 'normalises the title' do
      import

      expect(SearchReference.for_fpo.select_map(:title)).to contain_exactly('165ml brush cleaner', '100 ariel pods')
    end

    it 'pads 8 digit codes to 10 digits' do
      import

      expect(SearchReference.for_fpo.select_map(:goods_nomenclature_item_id).uniq).to eq(%w[3402509000])
    end

    it 'links to the goods nomenclature' do
      import

      expect(SearchReference.for_fpo.first).to have_attributes(
        goods_nomenclature_sid: commodity.goods_nomenclature_sid,
        referenced_class: 'Commodity',
        productline_suffix: '80',
      )
    end

    it 'returns the result' do
      expect(import.created.size).to eq(2)
    end

    it 'prints a summary' do
      import

      expect(output.string).to include('created: 2')
    end
  end

  context 'with a subheading code' do
    let(:rows) { [['17 mallow sponge', '39249000']] }

    before do
      parent = create(:commodity, :actual, goods_nomenclature_item_id: '3924900000')
      create(:commodity, :actual, goods_nomenclature_item_id: '3924900010', parent:)
    end

    it 'references the subheading' do
      import

      expect(SearchReference.for_fpo.first).to have_attributes(
        goods_nomenclature_item_id: '3924900000',
        referenced_class: 'Subheading',
      )
    end
  end

  context 'with invalid codes' do
    let(:rows) do
      [
        ['loreal faux brw tnt', 'dark brun'],
        ['seven digits', '3402509'],
        ['nine digits', '340250900'],
        ['', '3402509000'],
      ]
    end

    it 'does not create references' do
      expect { import }.not_to change(SearchReference, :count)
    end

    it 'reports the rows' do
      import

      expect(output.string).to include('invalid row: 4', 'line 2: "loreal faux brw tnt" -> "dark brun"')
    end
  end

  context 'with a code that does not resolve to a current goods nomenclature' do
    let(:rows) { [['unknown thing', '9999999999']] }

    it 'does not create a reference' do
      expect { import }.not_to change(SearchReference, :count)
    end

    it 'reports the row' do
      expect(import.unresolved_code.size).to eq(1)
    end
  end

  context 'with duplicate rows' do
    let(:rows) do
      [
        ['1kg car dehumidifier bag', '3402509000'],
        ['1KG car dehumidifier bag', '34025090'],
      ]
    end

    it 'creates one reference' do
      expect { import }.to change(SearchReference, :count).by(1)
    end

    it 'reports the duplicate' do
      expect(import.duplicate.size).to eq(1)
    end
  end

  context 'with one description mapped to different codes' do
    before { create(:commodity, :actual, goods_nomenclature_item_id: '3924900000') }

    let(:rows) do
      [
        %w[2xquiltedplws 3402509000],
        %w[2xquiltedplws 39249000],
      ]
    end

    it 'creates a reference for each code' do
      expect { import }.to change(SearchReference, :count).by(2)
    end
  end

  context 'when a matching reference already exists' do
    let(:rows) { [['Brush cleaner', '3402509000']] }

    before { create(:search_reference, title: 'brush cleaner', referenced: commodity) }

    it 'does not create a reference' do
      expect { import }.not_to change(SearchReference, :count)
    end

    it 'reports the row as already present' do
      expect(import.existing.size).to eq(1)
    end
  end

  context 'when the import runs twice' do
    let(:rows) { [['brush cleaner', '3402509000']] }

    it 'is idempotent' do
      described_class.call(csv_file.path, output:)

      expect { import }.not_to change(SearchReference, :count)
    end
  end

  context 'with a title that starts with a spreadsheet formula character' do
    let(:rows) { [['=cmd', '3402509000']] }

    it 'escapes the title' do
      import

      expect(SearchReference.for_fpo.first.title).to eq("'=cmd")
    end
  end

  context 'with a dry run' do
    subject(:import) { described_class.call(csv_file.path, dry_run: true, output:) }

    let(:rows) { [['brush cleaner', '3402509000']] }

    it 'does not persist references' do
      expect { import }.not_to change(SearchReference, :count)
    end

    it 'reports what it would create' do
      import

      expect(output.string).to include('[DRY RUN]', 'created: 1')
    end

    it 'does not keep paper trail versions' do
      expect { import }.not_to(change { Version.where(item_type: 'SearchReference').count })
    end
  end

  context 'with paper trail' do
    let(:rows) { [['brush cleaner', '3402509000']] }

    it 'records a create version with the default whodunnit' do
      import

      expect(SearchReference.for_fpo.first.versions.first).to have_attributes(event: 'create', whodunnit: 'fpo_csv_import')
    end

    it 'records the given whodunnit' do
      described_class.call(csv_file.path, output:, whodunnit: 'jane@example.com')

      expect(SearchReference.for_fpo.first.versions.select_map(:whodunnit)).to eq(%w[jane@example.com])
    end

    it 'restores the previous whodunnit' do
      TradeTariffRequest.whodunnit = 'previous'

      import

      expect(TradeTariffRequest.whodunnit).to eq('previous')
    end
  end

  context 'when the CSV does not exist' do
    subject(:import) { described_class.call('missing.csv', output:) }

    it { expect { import }.to raise_error(ArgumentError, /CSV not found/) }
  end
end
