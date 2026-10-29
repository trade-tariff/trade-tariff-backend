require 'rails_helper'

RSpec.describe Evaluation::RunWorkbook do
  subject(:xlsx) { described_class.call(run) }

  let(:synthetic_input_set) { create(:evaluation_synthetic_input_set, name: 'March sample') }
  let(:experiment) { create(:evaluation_experiment, name: 'Vector retrieval', synthetic_input_set_id: synthetic_input_set.id) }
  let(:run) do
    create(
      :evaluation_run,
      evaluation_experiment: experiment,
      status: 'partially_failed',
      label: 'vector based retrieval',
      intended_result_count: 5,
      result_count: 4,
      error_count: 1,
      gold_in_top1_count: 2,
      gold_in_top5_count: 3,
      total_cost_usd: 0.4,
      total_latency_seconds: 20,
      started_at: Time.utc(2026, 10, 27, 9, 30),
      completed_at: Time.utc(2026, 10, 27, 9, 45),
      error_summary: '1 result errored',
      persona_breakdown: {
        'original' => { 'result_count' => 2, 'gold_in_top1_count' => 1, 'gold_in_top5_count' => 2, 'total_cost_usd' => 0.1, 'total_latency_seconds' => 8 },
        'novice' => { 'result_count' => 2, 'gold_in_top1_count' => 1, 'gold_in_top5_count' => 1, 'total_cost_usd' => 0.3, 'total_latency_seconds' => 12 },
      },
    )
  end

  # Every worksheet row as { 'A' => cell value, 'B' => ... }. A blank cell has no key at all, so
  # "left blank" is checked as a missing key, not as an empty string. That covers a cell that was
  # never written and one that is written empty only to carry a number format. Text cells come
  # back as Strings and number cells as Floats, which is what tells the two apart.
  def sheet_rows(sheet_number)
    sheet = Nokogiri::XML(xlsx_entry(xlsx, "xl/worksheets/sheet#{sheet_number}.xml")).remove_namespaces!

    sheet.xpath('//row').map do |row|
      row.xpath('./c').filter_map { |cell| (value = cell_value(cell)) && [cell['r'][/\A[A-Z]+/], value] }.to_h
    end
  end

  def cell_value(cell)
    return cell.at_xpath('./is/t')&.text if cell['t'] == 'inlineStr'

    number = cell.at_xpath('./v')
    Float(number.text) if number
  end

  # Excel stores a date and time as days since 30 December 1899.
  def excel_serial(time)
    (time - Time.utc(1899, 12, 30)) / 86_400.0
  end

  describe 'the workbook' do
    it 'has a Summary sheet then a Results sheet' do
      names = Nokogiri::XML(xlsx_entry(xlsx, 'xl/workbook.xml')).remove_namespaces!.xpath('//sheet').map { |sheet| sheet['name'] }

      expect(names).to eq(%w[Summary Results])
    end
  end

  describe 'the Summary sheet' do
    let(:summary) { sheet_rows(1).to_h { |row| [row['A'], row['B']] } }

    it 'names the run, its label, experiment and source set' do
      expect(summary.slice('Run', 'Label', 'Experiment', 'Source set')).to eq(
        'Run' => run.id.to_f,
        'Label' => 'vector based retrieval',
        'Experiment' => 'Vector retrieval',
        'Source set' => 'March sample',
      )
    end

    it 'shows the status in words' do
      expect(summary['Status']).to eq('Partially failed')
    end

    it 'counts the results done, expected and failed' do
      expect(summary.slice('Results done', 'Results expected', 'Results failed')).to eq(
        'Results done' => 4.0,
        'Results expected' => 5.0,
        'Results failed' => 1.0,
      )
    end

    it 'gives top 1 and top 5 accuracy as fractions of the results done' do
      expect(summary.slice('Top 1 accuracy', 'Top 5 accuracy')).to eq('Top 1 accuracy' => 0.5, 'Top 5 accuracy' => 0.75)
    end

    it 'gives total cost, average cost per result and average latency' do
      expect(summary.slice('Total cost (USD)', 'Average cost per result (USD)', 'Average latency (seconds)')).to eq(
        'Total cost (USD)' => 0.4,
        'Average cost per result (USD)' => 0.1,
        'Average latency (seconds)' => 5.0,
      )
    end

    # Excel keeps a date as a decimal number of days, so the last few digits are float noise.
    it 'gives the started time as an Excel date in UTC' do
      expect(summary['Started (UTC)']).to be_within(1e-9).of(excel_serial(Time.utc(2026, 10, 27, 9, 30)))
    end

    it 'gives the completed time as an Excel date in UTC' do
      expect(summary['Completed (UTC)']).to be_within(1e-9).of(excel_serial(Time.utc(2026, 10, 27, 9, 45)))
    end

    it 'includes the error summary' do
      expect(summary['Error summary']).to eq('1 result errored')
    end

    it 'counts the results with unknown pricing, even when there are none' do
      expect(summary['Results with unknown pricing']).to eq(0.0)
    end

    it 'has no cost warning when every result was priced' do
      expect(summary).not_to have_key('Cost warning')
    end

    context 'when some results have unknown pricing' do
      let(:run) { create(:evaluation_run, evaluation_experiment: experiment, result_count: 4, total_cost_usd: 0.4, unpriced_result_count: 2) }

      it 'counts them' do
        expect(summary['Results with unknown pricing']).to eq(2.0)
      end

      it 'warns that the cost figures may be understated' do
        expect(summary['Cost warning']).to eq('2 results have unknown pricing, so the total and average cost may be understated.')
      end

      it 'keeps the cost cells as numbers' do
        expect(summary.values_at('Total cost (USD)', 'Average cost per result (USD)')).to eq([0.4, 0.1])
      end
    end

    context 'when the run has no results yet' do
      let(:run) { create(:evaluation_run, evaluation_experiment: experiment, status: 'cancelled', result_count: 0) }

      it 'leaves the accuracy and averages blank instead of dividing by zero' do
        expect(summary.values_at('Top 1 accuracy', 'Top 5 accuracy', 'Average cost per result (USD)', 'Average latency (seconds)')).to all(be_nil)
      end

      it 'leaves the dates blank' do
        expect(summary.values_at('Started (UTC)', 'Completed (UTC)')).to all(be_nil)
      end
    end

    context 'when the experiment has no source set' do
      let(:experiment) { create(:evaluation_experiment) }

      it 'leaves the source set blank' do
        expect(summary['Source set']).to be_nil
      end
    end
  end

  describe 'the By persona table on the Summary sheet' do
    let(:persona_rows) { sheet_rows(1).drop_while { |row| row['A'] != 'Persona' } }

    it 'starts with a header row' do
      expect(persona_rows.first.values).to eq(
        ['Persona', 'Results', 'Top 1 accuracy', 'Top 5 accuracy', 'Average cost (USD)', 'Average latency (seconds)'],
      )
    end

    it 'has one row per persona, sorted by persona name' do
      expect(persona_rows.drop(1).map(&:values)).to eq(
        [['novice', 2.0, 0.5, 0.5, 0.15, 6.0], ['original', 2.0, 0.5, 1.0, 0.05, 4.0]],
      )
    end
  end

  describe 'the Results sheet' do
    let(:rows) { sheet_rows(2) }

    # One result that passed, one that failed and one that errored, created in this order so
    # their ids (and so the row order in the sheet) follow it.
    before do
      create(:evaluation_result, evaluation_run: run, source_type: 'synthetic_atar', source_id: '8', persona: 'original',
                                 expected_code: '8471300000', final_code: '8471300000', final_rank: 1,
                                 gold_in_top1: true, gold_in_top5: true, latency_seconds: 4.5, cost_usd: 0.0123, pricing_known: true)
      create(:evaluation_result, evaluation_run: run, source_type: 'synthetic_atar', source_id: '9', persona: 'novice',
                                 expected_code: '8517120000', final_code: '8517130000', final_rank: 7,
                                 gold_in_top1: false, gold_in_top5: false, latency_seconds: 6, cost_usd: 0.02, pricing_known: true)
      create(:evaluation_result, evaluation_run: run, source_type: 'synthetic_atar', source_id: '10', persona: 'novice',
                                 expected_code: '6109100010', error: 'Session failed', gold_in_top1: false, gold_in_top5: false,
                                 pricing_known: false)
    end

    it 'starts with a header row' do
      expect(rows.first.values).to eq(
        ['Source type', 'Source ID', 'Persona', 'Expected code', 'Returned code', 'Rank', 'Outcome', 'Cost (USD)', 'Latency (seconds)', 'Error'],
      )
    end

    it 'has one row per result, in the order they were recorded' do
      expect(rows.drop(1).map { |row| row['B'] }).to eq(%w[8 9 10])
    end

    it 'says Pass when the expected code was in the top 5, Error when the result has an error, and Fail otherwise' do
      expect(rows.drop(1).map { |row| row['G'] }).to eq(%w[Pass Fail Error])
    end

    it 'writes cost and latency as numbers so Excel can sort and add them' do
      expect(rows[1].values_at('H', 'I')).to eq([0.0123, 4.5])
    end

    it 'leaves cost blank when the pricing is unknown, instead of writing text into a number column' do
      expect(rows[3].key?('H')).to be(false)
    end

    it 'leaves the returned code, rank and latency blank when the result has none' do
      expect(rows[3].values_at('E', 'F', 'I')).to all(be_nil)
    end

    it 'includes the error message' do
      expect(rows[3]['J']).to eq('Session failed')
    end

    it 'leaves out the results of other runs' do
      create(:evaluation_result, evaluation_run: create(:evaluation_run, evaluation_experiment: experiment))

      expect(rows.size).to eq(4)
    end

    context 'with more results than fit on one page of the results list' do
      before { create_list(:evaluation_result, 25, evaluation_run: run) }

      it 'includes every result' do
        expect(rows.size).to eq(1 + 3 + 25)
      end
    end
  end
end
