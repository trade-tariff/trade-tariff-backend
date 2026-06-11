RSpec.describe Api::User::ActiveCommoditiesReportService do
  let(:active_codes) { Set.new(%w[2222222222]) }
  let(:expired_codes) { Set.new(%w[1111111111]) }
  let(:invalid_codes) { Set.new(%w[3333333333]) }

  before do
    create(
      :chapter,
      :with_description,
      goods_nomenclature_item_id: '1100000000',
      goods_nomenclature_sid: 11,
      description: 'Chapter Eleven',
    )

    create(
      :chapter,
      :with_description,
      goods_nomenclature_item_id: '2200000000',
      goods_nomenclature_sid: 22,
      description: 'Chapter Twenty Two',
    )

    create(
      :commodity,
      :expired,
      :with_description,
      goods_nomenclature_item_id: '1111111111',
      goods_nomenclature_sid: 111,
      description: 'Expired commodity description',
    )

    create(
      :commodity,
      :actual,
      :with_description,
      goods_nomenclature_item_id: '2222222222',
      goods_nomenclature_sid: 222,
      description: 'Active commodity<br>description',
    )
  end

  describe '.call' do
    it 'delegates to an instance call' do
      instance = instance_double(described_class, call: :package)
      allow(described_class).to receive(:new).and_return(instance)

      result = described_class.call(active_codes, expired_codes, invalid_codes)

      expect(result).to eq(:package)
    end
  end

  describe '#call' do
    subject(:package) { described_class.new(active_codes, expired_codes, invalid_codes).call }

    let(:builder_class) { Api::User::ActiveCommoditiesReportWorksheetBuilder }
    let(:xlsx_data) { package.read_string }

    it 'creates a FastExcel workbook' do
      expect(package).to be_a(Libxlsxwriter::Workbook)
    end

    it 'creates a worksheet named Your commodities' do
      workbook_xml = xlsx_entry(xlsx_data, 'xl/workbook.xml')

      expect(workbook_xml).to include('name="Your commodities"')
    end

    it 'adds the title and instructions before the table' do
      freeze_time do
        dated_package = described_class.new(active_codes, expired_codes, invalid_codes).call
        rows = worksheet_row_texts(dated_package.read_string)
        expected_date = Time.zone.today.strftime('%d/%m/%Y')

        expect(rows[0]).to eq(['Your commodities', "(#{expected_date})"])
        expect(rows[1]).to eq(['Updating your commodity watch list:'])
        expect(rows[2]).to eq(['All your active and expired codes, as well as errors, are listed on this spreadsheet.'])
        expect(rows[3]).to eq(['You can edit, add and remove codes from this spreadsheet or your own.'])
        expect(rows[4]).to eq([
          'You can then upload it to update your commodity watchlist. ',
          'Ensure all codes are listed in column A.',
        ])
      end
    end

    it 'adds a replace all upload link row before the table' do
      rows = worksheet_row_texts(xlsx_data)

      expect(rows[5]).to eq(['Replace all commodities (upload)'])
      expect(worksheet_relationships_xml(xlsx_data)).to include(xml_escape(builder_class::REPLACE_ALL_COMMODITIES_UPLOAD_URL))
    end

    it 'adds rows ordered by commodity code with chapter, description and status' do
      rows = worksheet_row_texts(xlsx_data)

      expect(rows[7]).to eq(%w[Commodity Chapter Description Status])
      expect(rows[8]).to eq(["1111111111\n ", '11: Chapter eleven', 'Expired commodity description', "\n", 'Expired'])
      expect(rows[9]).to eq(["2222222222\n ", '22: Chapter twenty two', "Active commodity\ndescription", "\n", 'Active'])
      expect(rows[10]).to eq(["3333333333\n ", 'Not applicable', 'Not applicable', 'Error from upload'])
    end

    it 'renders rich text emphasis for the final instruction and valid descriptions' do
      xml = worksheet_xml(xlsx_data)

      expect(xml).to match(%r{<r><rPr><b/>.*?</rPr><t>Ensure all codes are listed in column A\.</t></r>}m)
      expect(xml).to match(%r{<r><rPr><b/>.*?</rPr><t>Expired commodity description</t></r>}m)
      expect(xml).to match(%r{<r><rPr><b/>.*?</rPr><t>Active commodity\n?description</t></r>}m)
    end

    it 'adds table styling for the full data range' do
      xml = worksheet_xml(xlsx_data)

      expect(xml).to include('<autoFilter ref="A8:D11"/>')
    end
  end

  describe '#load_classification_descriptions' do
    subject(:service) { described_class.new(active_codes, expired_codes, invalid_codes) }

    let(:codes) { %w[1111111111 2222222222] }

    it 'delegates to CachedCommodityDescriptionService.fetch_for_codes' do
      allow(CachedCommodityDescriptionService).to receive(:fetch_for_codes).with(codes, include_hierarchy: true).and_return(
        '1111111111' => { plain_description: 'Cached 111', hierarchy_levels: ['Cached 111'], has_heading: false },
        '2222222222' => { plain_description: 'Fetched 222', hierarchy_levels: ['Fetched 222'], has_heading: false },
      )

      result = service.send(:load_classification_descriptions, codes)

      expect(result).to eq(
        '1111111111' => { plain_description: 'Cached 111', hierarchy_levels: ['Cached 111'], has_heading: false },
        '2222222222' => { plain_description: 'Fetched 222', hierarchy_levels: ['Fetched 222'], has_heading: false },
      )
      expect(CachedCommodityDescriptionService).to have_received(:fetch_for_codes).with(codes, include_hierarchy: true)
    end
  end
end
