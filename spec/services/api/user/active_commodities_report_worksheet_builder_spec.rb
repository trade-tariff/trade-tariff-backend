RSpec.describe Api::User::ActiveCommoditiesReportWorksheetBuilder do
  describe '.call' do
    subject(:xlsx_data) do
      described_class.call(workbook:, report_rows:)
      workbook.read_string
    end

    let(:workbook) { FastExcel.open(constant_memory: true) }
    let(:report_rows) do
      [
        {
          code: '1111111111',
          chapter: '11: Chapter eleven',
          description: {
            plain_description: 'Expired commodity description',
            hierarchy_levels: ['Expired commodity description'],
            has_heading: false,
          },
          status: Api::User::ActiveCommoditiesReportService::EXPIRED,
        },
        {
          code: '2222222222',
          chapter: '22: Chapter twenty two',
          description: {
            plain_description: 'Active commodity description',
            hierarchy_levels: ['Active commodity description'],
            has_heading: false,
          },
          status: Api::User::ActiveCommoditiesReportService::ACTIVE,
        },
        {
          code: '3333333333',
          chapter: 'Not applicable',
          description: 'Not applicable',
          status: Api::User::ActiveCommoditiesReportService::ERROR_FROM_UPLOAD,
        },
      ]
    end

    it 'renders title, instructions and rows' do
      freeze_time do
        expect(worksheet_row_texts(xlsx_data)).to include(
          ['Your commodities', "(#{Time.zone.today.strftime('%d/%m/%Y')})"],
          ['Updating your commodity watch list:'],
          ['All your active and expired codes, as well as errors, are listed on this spreadsheet.'],
          ['You can edit, add and remove codes from this spreadsheet or your own.'],
          ['You can then upload it to update your commodity watchlist. ', 'Ensure all codes are listed in column A.'],
          described_class::HEADERS,
          ["1111111111\n ", '11: Chapter eleven', 'Expired commodity description', "\n", 'Expired'],
          ["2222222222\n ", '22: Chapter twenty two', 'Active commodity description', "\n", 'Active'],
          ["3333333333\n ", 'Not applicable', 'Not applicable', 'Error from upload'],
        )
      end
    end

    it 'writes rich text for bold fragments' do
      xml = worksheet_xml(xlsx_data)

      expect(xml).to match(%r{<r><rPr><b/>.*?</rPr><t>Ensure all codes are listed in column A\.</t></r>}m)
      expect(xml).to match(%r{<r><rPr><b/>.*?</rPr><t>Expired commodity description</t></r>}m)
    end

    it 'adds the upload hyperlink and filters' do
      expect(worksheet_relationships_xml(xlsx_data)).to include(xml_escape(described_class::REPLACE_ALL_COMMODITIES_UPLOAD_URL))
      expect(worksheet_xml(xlsx_data)).to include('<autoFilter ref="A8:D11"/>')
    end

    context 'when there are no report rows' do
      let(:report_rows) { [] }

      it 'does not add a filter range' do
        expect(worksheet_xml(xlsx_data)).not_to include('<autoFilter')
      end
    end
  end
end
