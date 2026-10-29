module Evaluation
  # The Excel workbook an operator downloads from the admin run list (AI-1494): the run's summary on
  # one sheet and one row per result on another. The summary mirrors the Summary and By persona
  # sections of the admin run page, worked out from the same totals stored on the run, so the two
  # always agree. Returns the file's bytes.
  #
  # Cost and latency are written as numbers, never as text, so Excel can sort and add them up. A
  # value that is missing is left as a blank cell (FastExcel writes no cell for nil).
  class RunWorkbook
    SUMMARY_SHEET = 'Summary'.freeze
    RESULTS_SHEET = 'Results'.freeze

    PERSONA_HEADERS = ['Persona', 'Results', 'Top 1 accuracy', 'Top 5 accuracy', 'Average cost (USD)', 'Average latency (seconds)'].freeze
    RESULT_HEADERS = ['Source type', 'Source ID', 'Persona', 'Expected code', 'Returned code', 'Rank', 'Outcome', 'Cost (USD)', 'Latency (seconds)', 'Error'].freeze

    def self.call(run)
      new(run).call
    end

    def initialize(run)
      @run = run
    end

    def call
      write_summary_sheet
      write_results_sheet
      workbook.read_string
    end

  private

    attr_reader :run

    def workbook
      @workbook ||= FastExcel.open(constant_memory: true)
    end

    def bold
      @bold ||= workbook.bold_format
    end

    def percent
      @percent ||= workbook.number_format('0%')
    end

    def cost
      @cost ||= workbook.number_format('0.00000')
    end

    def seconds
      @seconds ||= workbook.number_format('0.00')
    end

    def timestamp
      @timestamp ||= workbook.number_format('yyyy-mm-dd hh:mm:ss')
    end

    def write_summary_sheet
      sheet = workbook.add_worksheet(SUMMARY_SHEET)
      sheet.set_column_width(0, 32)
      sheet.set_column_width(1, 30)

      summary_rows.each { |label, value, format| sheet.append_row([label, value], [bold, format]) }
      write_persona_table(sheet)
    end

    def summary_rows
      experiment = run.evaluation_experiment

      [
        ['Run', run.id, nil],
        ['Label', run.label, nil],
        ['Experiment', experiment&.name, nil],
        ['Source set', experiment&.source_name, nil],
        ['Status', run.status.humanize, nil],
        ['Results done', run.result_count, nil],
        ['Results expected', run.intended_result_count, nil],
        ['Results failed', run.error_count, nil],
        ['Top 1 accuracy', rate(run.gold_in_top1_count, run.result_count), percent],
        ['Top 5 accuracy', rate(run.gold_in_top5_count, run.result_count), percent],
        ['Total cost (USD)', run.total_cost_usd&.to_f, cost],
        ['Average cost per result (USD)', average(run.total_cost_usd, run.result_count), cost],
        ['Average latency (seconds)', average(run.total_latency_seconds, run.result_count), seconds],
        ['Results with unknown pricing', run.unpriced_result_count, nil],
        *cost_warning_row,
        ['Started (UTC)', run.started_at&.getutc, timestamp],
        ['Completed (UTC)', run.completed_at&.getutc, timestamp],
        ['Error summary', run.error_summary, nil],
      ]
    end

    # The stored total only adds up the results that could be priced, so with any unpriced
    # result it is understated. The run page says so; the workbook must too, as text beside
    # the cost cells, which stay numbers.
    def cost_warning_row
      unpriced = run.unpriced_result_count.to_i
      return [] unless unpriced.positive?

      [['Cost warning', "#{unpriced} #{'result'.pluralize(unpriced)} #{unpriced == 1 ? 'has' : 'have'} unknown pricing, so the total and average cost may be understated.", nil]]
    end

    # One row per persona that has results, sorted by name -- the same table the run page shows.
    # The backend keeps no list of personas: whatever string each result carries is what appears.
    def write_persona_table(sheet)
      personas = run.persona_breakdown.to_h.sort_by { |persona, _stats| persona }
      return if personas.empty?

      sheet.append_row([])
      sheet.append_row(['By persona'], bold)
      sheet.append_row(PERSONA_HEADERS, bold)
      personas.each { |persona, stats| sheet.append_row(persona_row(persona, stats), [nil, nil, percent, percent, cost, seconds]) }
    end

    def persona_row(persona, stats)
      count = stats['result_count'].to_i

      [
        persona,
        count,
        rate(stats['gold_in_top1_count'], count),
        rate(stats['gold_in_top5_count'], count),
        average(stats['total_cost_usd'], count),
        average(stats['total_latency_seconds'], count),
      ]
    end

    def write_results_sheet
      sheet = workbook.add_worksheet(RESULTS_SHEET)
      RESULT_HEADERS.each_index { |index| sheet.set_column_width(index, 18) }
      sheet.set_column_width(RESULT_HEADERS.index('Error'), 60)

      results = EvaluationResult.where(run_id: run.id).order(:id).all
      sheet.append_row(RESULT_HEADERS, bold)
      results.each { |result| sheet.append_row(result_row(result), [nil, nil, nil, nil, nil, nil, nil, cost, seconds, nil]) }
      sheet.freeze_panes(1, 0)
      sheet.autofilter(0, 0, results.size, RESULT_HEADERS.size - 1)
    end

    def result_row(result)
      [
        result.source_type,
        result.source_id,
        result.persona,
        result.expected_code,
        result.final_code,
        result.final_rank,
        outcome(result),
        result.pricing_known ? result.cost_usd&.to_f : nil,
        result.latency_seconds&.to_f,
        result.error,
      ]
    end

    # The same three-way split as the results list's Outcome filter (ResultsController#filter_by_outcome).
    def outcome(result)
      return 'Pass' if result.gold_in_top5
      return 'Error' if result.error.present?

      'Fail'
    end

    def rate(count, total)
      return nil if total.to_i.zero?

      count.to_f / total
    end

    def average(total, count)
      return nil if count.to_i.zero?

      total.to_f / count
    end
  end
end
