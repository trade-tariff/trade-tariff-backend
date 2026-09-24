RSpec.describe SearchExport::Workbook do
  let(:from) { Date.new(2026, 9, 23) }
  let(:to) { Date.new(2026, 9, 23) }
  let(:generated_at) { Time.utc(2026, 9, 24, 12) }

  def store_journey(**overrides)
    SearchExport::Journey.upsert_terminal({
      request_id: 'journey-1',
      service: TradeTariffBackend.service,
      request_source: 'frontend',
      query: 'frozen chicken',
      expansion_terms: Sequel.pg_jsonb([]),
      answers: Sequel.pg_jsonb([]),
      end_page_type: 'Result',
      results: Sequel.pg_jsonb([{ 'commodity_code' => '0207141000', 'description' => 'Frozen cuts', 'confidence_label' => 'Strong' }]),
      terminal_at: Time.utc(2026, 9, 23, 10),
    }.merge(overrides))
  end

  def workbook
    described_class.call(from:, to:, generated_at:)
  end

  def sheet_xml(bytes, name)
    xml = nil
    Zip::File.open_buffer(StringIO.new(bytes)) { |zip| xml = zip.read(name) }
    xml
  end

  it 'accounts for wrapping in narrow columns without explicit newlines' do
    store_journey(query: 'frozen chicken breast ' * 10)
    document = Nokogiri::XML(sheet_xml(workbook.bytes, 'xl/worksheets/sheet2.xml'))
    document.remove_namespaces!

    expect(document.at_xpath('//row[@r="3"]')['ht'].to_f).to be > 15
  end

  it 'removes XML control characters without turning query text into markup' do
    store_journey(query: "chicken\x01 & <cuts>")
    xml = sheet_xml(workbook.bytes, 'xl/worksheets/sheet2.xml')

    expect { Nokogiri::XML(xml, &:strict) }.not_to raise_error
    expect(xml).to include('chicken &amp; &lt;cuts&gt;')
  end

  it 'writes each journey once across batches and bounds click queries to each batch' do
    stub_const('SearchExport::Workbook::BATCH_SIZE', 2)
    5.times { |index| store_journey(request_id: "journey-#{index}") }
    allow(SearchExport::ResultClick).to receive(:where).and_call_original

    result = workbook

    expect(result.row_count).to eq(5)
    expect(SearchExport::ResultClick).to have_received(:where).with(request_id: %w[journey-0 journey-1])
    expect(SearchExport::ResultClick).to have_received(:where).with(request_id: %w[journey-2 journey-3])
    expect(SearchExport::ResultClick).to have_received(:where).with(request_id: %w[journey-4])
    expect(sheet_xml(result.bytes, 'xl/worksheets/sheet2.xml')).to include('ref="A1:AI7"')
  end

  it 'fails explicitly when the template dimensions change' do
    builder = described_class.new(from:, to:, generated_at:)
    expect { builder.send(:write_searches, StringIO.new, '<sheetData></sheetData>', StringIO.new, 0) }
      .to raise_error('Unexpected classifier template dimensions')
  end

  it 'writes an inline string for a term that starts with =' do
    store_journey(query: '=chicken')

    xml = sheet_xml(workbook.bytes, 'xl/worksheets/sheet2.xml')

    expect(xml).to include('<t>=chicken</t>')
    expect(xml).not_to include('<f>=chicken</f>')
    expect(xml).to include('customHeight="1"')
  end

  it 'keeps the template dropdowns, outline and summary formula' do
    store_journey

    searches = sheet_xml(workbook.bytes, 'xl/worksheets/sheet2.xml')
    summary = sheet_xml(workbook.bytes, 'xl/worksheets/sheet4.xml')

    expect(searches).to include('formula1>"Yes,No"</formula1>')
    expect(searches).to include('outlineLevel="1"')
    expect(summary).to include('COUNTA(Searches!$A$3:$A$1048576)')
  end

  it 'writes seven question groups and leaves later groups blank' do
    answers = Array.new(7) { |index| { 'question' => "Question #{index}", 'options' => %w[Yes No], 'answer' => 'Yes' } }
    store_journey(answers: Sequel.pg_jsonb(answers))

    xml = sheet_xml(workbook.bytes, 'xl/worksheets/sheet2.xml')

    expect(xml).to include('Question 0')
    expect(xml).to include('Question 6')
    expect(xml).to include('r="Y3"')
  end

  it 'writes cells in worksheet order and leaves review columns empty' do
    store_journey(answers: Sequel.pg_jsonb([{ 'question' => 'Cut?', 'options' => %w[Fillet Whole], 'answer' => 'Fillet' }]))
    document = Nokogiri::XML(sheet_xml(workbook.bytes, 'xl/worksheets/sheet2.xml'))
    document.remove_namespaces!

    expect(document.xpath('//row[@r="3"]/c').map { |cell| cell['r'] }).to eq(%w[A3 B3 C3 E3 F3 G3 Z3 AA3 AB3])
  end

  it 'preserves every template entry except the two sheets receiving data' do
    store_journey
    bytes = workbook.bytes

    Zip::File.open(described_class::TEMPLATE) do |template|
      Zip::File.open_buffer(StringIO.new(bytes)) do |output|
        template.each do |entry|
          next if [described_class::SEARCHES_SHEET, described_class::INSTRUCTIONS_SHEET].include?(entry.name)

          expect(output.read(entry.name)).to eq(template.read(entry.name)), "Changed template entry: #{entry.name}"
        end
      end
    end
  end

  it 'omits a selected answer that was not offered and reports the count' do
    store_journey(answers: Sequel.pg_jsonb([{ 'question' => 'Cut?', 'options' => %w[Fillet], 'answer' => 'Whole' }]))

    result = workbook

    expect(result.row_count).to eq(0)
    expect(result.omitted_count).to eq(1)
    expect(sheet_xml(result.bytes, 'xl/worksheets/sheet1.xml')).to include('Omitted journeys: 1')
    expect(sheet_xml(result.bytes, 'xl/worksheets/sheet2.xml')).not_to include('journey-1')
  end

  it 'writes the first click for each code, including a click after the range end' do
    store_journey
    SearchExport::ResultClick.record(request_id: 'journey-1', commodity_code: '0207141000', result_rank: 2, clicked_at: Time.utc(2026, 9, 24, 1))
    SearchExport::ResultClick.record(request_id: 'journey-1', commodity_code: '0207141000', result_rank: 1, clicked_at: Time.utc(2026, 9, 23, 11))

    xml = sheet_xml(workbook.bytes, 'xl/worksheets/sheet2.xml')

    expect(xml).to include('0207141000 - Frozen cuts')
    expect(xml.scan('0207141000 - Frozen cuts').size).to eq(2)
  end

  it 'keeps distinct clicks in first-click order through the generation cutoff' do
    results = %w[0207141000 0207141001 0207141002].map do |code|
      { 'commodity_code' => code, 'description' => "Cuts #{code}", 'confidence_label' => 'Good' }
    end
    store_journey(results: Sequel.pg_jsonb(results))
    [
      ['0207141001', Time.utc(2026, 9, 23, 11)],
      ['0207141000', Time.utc(2026, 9, 24, 1)],
      ['0207141001', Time.utc(2026, 9, 24, 2)],
      ['0207141002', generated_at + 1],
      ['9999999999', Time.utc(2026, 9, 24, 3)],
    ].each do |code, clicked_at|
      SearchExport::ResultClick.record(request_id: 'journey-1', commodity_code: code, result_rank: 1, clicked_at:)
    end

    document = Nokogiri::XML(sheet_xml(workbook.bytes, 'xl/worksheets/sheet2.xml'))
    document.remove_namespaces!

    expect(document.at_xpath('//c[@r="AC3"]/is/t').text).to eq("0207141001 - Cuts 0207141001\n0207141000 - Cuts 0207141000")
  end

  %w[= + - @].each do |prefix|
    it "stores a query starting with #{prefix} as text, not a formula" do
      store_journey(query: "#{prefix}chicken")

      document = Nokogiri::XML(sheet_xml(workbook.bytes, 'xl/worksheets/sheet2.xml'))
      document.remove_namespaces!
      cell = document.at_xpath('//c[@r="B3"]')

      expect(cell['t']).to eq('inlineStr')
      expect(cell.at_xpath('is/t').text).to eq("#{prefix}chicken")
      expect(cell.at_xpath('f')).to be_nil
    end
  end

  it 'returns headers and zero omissions when the range has no available journeys' do
    result = workbook
    document = Nokogiri::XML(sheet_xml(result.bytes, 'xl/worksheets/sheet2.xml'))
    document.remove_namespaces!

    expect(result).to have_attributes(row_count: 0, omitted_count: 0)
    expect(document.xpath('//sheetData/row').map { |row| row['r'] }).to eq(%w[1 2])
  end

  it 'includes only available journeys and counts only stored omissions across a sparse range' do
    store_journey
    store_journey(request_id: 'invalid-journey', query: '')
    store_journey(request_id: 'outside-range', terminal_at: Time.utc(2026, 9, 25))

    result = described_class.call(from: Date.new(2026, 1, 1), to:, generated_at:)
    xml = sheet_xml(result.bytes, 'xl/worksheets/sheet2.xml')

    expect(result).to have_attributes(row_count: 1, omitted_count: 1)
    expect(xml).to include('journey-1')
    expect(xml).not_to include('invalid-journey', 'outside-range')
  end

  it 'leaves expansion blank when no terms were stored' do
    store_journey

    xml = sheet_xml(workbook.bytes, 'xl/worksheets/sheet2.xml')

    expect(xml).to include('>No</t>')
    expect(xml).not_to include('r="D3"')
  end
end
