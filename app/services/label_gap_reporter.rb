class LabelGapReporter
  def self.call(chapter_code)
    new(chapter_code).call
  end

  def initialize(chapter_code)
    @chapter_code = chapter_code
  end

  def call
    TimeMachine.now do
      context = label_gap_context
      print_chapter_gap_summary(context)
      print_heading_gap_details(context)
    end
  end

private

  attr_reader :chapter_code

  def label_gap_context
    goods_nomenclatures_table = Sequel[:goods_nomenclatures]
    labels_table = Sequel[:goods_nomenclature_labels]
    self_texts_table = Sequel[:goods_nomenclature_self_texts]
    base = label_gap_base_dataset(goods_nomenclatures_table, labels_table, self_texts_table)
    expressions = label_gap_expressions(labels_table, self_texts_table)
    chapter_stats = label_gap_chapter_stats(base, goods_nomenclatures_table, expressions)

    { goods_nomenclatures_table:, labels_table:, self_texts_table:, base:, expressions:, chapter_stats:, chapter_descs: chapter_descriptions }
  end

  def label_gap_base_dataset(goods_nomenclatures_table, labels_table, self_texts_table)
    base = GoodsNomenclature.actual
      .non_hidden
      .with_leaf_column
      .declarable
      .left_join(:goods_nomenclature_labels, { labels_table[:goods_nomenclature_sid] => goods_nomenclatures_table[:goods_nomenclature_sid] })
      .left_join(:goods_nomenclature_self_texts, { self_texts_table[:goods_nomenclature_sid] => goods_nomenclatures_table[:goods_nomenclature_sid] })

    return base unless chapter_code

    base.where(Sequel.like(goods_nomenclatures_table[:goods_nomenclature_item_id], "#{chapter_code.ljust(2, '0')}%"))
  end

  def label_gap_expressions(labels_table, self_texts_table)
    {
      unlabeled: Sequel.expr(labels_table[:goods_nomenclature_sid] => nil),
      stale: Sequel.&({ labels_table[:stale] => true }, { labels_table[:manually_edited] => false }),
      drifted: Sequel.&(
        { labels_table[:manually_edited] => false },
        Sequel.~(self_texts_table[:self_text] => nil),
        Sequel.~(labels_table[:context_hash] => GoodsNomenclatureLabel.self_text_hash(self_texts_table)),
      ),
    }
  end

  def label_gap_chapter_stats(base, goods_nomenclatures_table, expressions)
    base
      .select_group(Sequel.function(:substr, goods_nomenclatures_table[:goods_nomenclature_item_id], 1, 2).as(:ch))
      .select_append { count(Sequel.lit('*')).as(total) }
      .select_append { count(Sequel.case([[expressions[:unlabeled], 1]], nil)).as(missing) }
      .select_append { count(Sequel.case([[expressions[:stale], 1]], nil)).as(stale) }
      .select_append { count(Sequel.case([[expressions[:drifted], 1]], nil)).as(drifted) }
      .order(:ch)
      .all
  end

  def chapter_descriptions
    Chapter.actual
      .eager(:goods_nomenclature_descriptions)
      .all
      .to_h { |chapter| [chapter.goods_nomenclature_item_id.first(2), chapter.description&.truncate(40)] }
  end

  def print_chapter_gap_summary(context)
    $stdout.puts 'Label Gaps, Stale and Context-Drifted by Chapter'
    $stdout.puts '=' * 110
    $stdout.printf "%-4s %-40s %6s %6s %6s %6s %6s %7s\n", 'Ch', 'Description', 'Total', 'Miss', 'Stale', 'Drift', 'Work', 'Cov %'
    $stdout.puts '-' * 110
    context[:chapter_stats].each { |row| print_chapter_gap_row(row, context[:chapter_descs]) }
    print_chapter_gap_total(context[:chapter_stats])
  end

  def print_chapter_gap_row(row, chapter_descs)
    total = row[:total]
    work = row[:missing] + row[:stale] + row[:drifted]
    coverage = total.positive? ? ((total - row[:missing]) * 100.0 / total).round(1) : 0

    $stdout.printf "%-4s %-40s %6d %6d %6d %6d %6d %6.1f%%\n",
                   row[:ch], chapter_descs[row[:ch]] || '?', total, row[:missing], row[:stale], row[:drifted], work, coverage
  end

  def print_chapter_gap_total(chapter_stats)
    totals = chapter_gap_totals(chapter_stats)
    $stdout.puts '-' * 110
    $stdout.printf "%-45s %6d %6d %6d %6d %6d %6.1f%%\n",
                   'TOTAL', totals[:total], totals[:missing], totals[:stale], totals[:drifted], totals[:work], totals[:coverage]
    $stdout.puts
  end

  def chapter_gap_totals(chapter_stats)
    total = chapter_stats.sum { |row| row[:total] }
    missing = chapter_stats.sum { |row| row[:missing] }
    stale = chapter_stats.sum { |row| row[:stale] }
    drifted = chapter_stats.sum { |row| row[:drifted] }
    work = missing + stale + drifted
    coverage = total.positive? ? ((total - missing) * 100.0 / total).round(1) : 0

    { total:, missing:, stale:, drifted:, work:, coverage: }
  end

  def print_heading_gap_details(context)
    if gap_chapters(context[:chapter_stats]).any?
      print_headings_with_gaps(context)
    else
      $stdout.puts 'No gaps found - full coverage, nothing stale or drifted!'
    end
  end

  def gap_chapters(chapter_stats)
    chapter_stats.select { |row| (row[:missing] + row[:stale] + row[:drifted]).positive? }.map { |row| row[:ch] }
  end

  def print_headings_with_gaps(context)
    heading_stats = label_gap_heading_stats(context)
    heading_descs = heading_descriptions

    $stdout.puts 'Labels Needing Work by Heading'
    $stdout.puts '=' * 90
    $stdout.printf "%-6s %-40s %6s %6s %6s %6s\n", 'Head', 'Description', 'Miss', 'Stale', 'Drift', 'Work'
    $stdout.puts '-' * 90
    print_heading_gap_rows(heading_stats, context[:chapter_descs], heading_descs)
    $stdout.puts
    print_commodity_work_rows(context)
  end

  def label_gap_heading_stats(context)
    expressions = context[:expressions]
    needing_work_dataset(context).select_group(
      Sequel.function(:substr, context[:goods_nomenclatures_table][:goods_nomenclature_item_id], 1, 2).as(:ch),
      Sequel.function(:substr, context[:goods_nomenclatures_table][:goods_nomenclature_item_id], 1, 4).as(:hd),
    )
      .select_append { count(Sequel.case([[expressions[:unlabeled], 1]], nil)).as(missing) }
      .select_append { count(Sequel.case([[expressions[:stale], 1]], nil)).as(stale) }
      .select_append { count(Sequel.case([[expressions[:drifted], 1]], nil)).as(drifted) }
      .order(:ch, :hd)
      .all
  end

  def needing_work_dataset(context)
    expressions = context[:expressions]
    context[:base].where(expressions[:unlabeled] | expressions[:stale] | expressions[:drifted])
  end

  def heading_descriptions
    Heading.actual
      .eager(:goods_nomenclature_descriptions)
      .all
      .to_h { |heading| [heading.goods_nomenclature_item_id.first(4), heading.description&.truncate(40)] }
  end

  def print_heading_gap_rows(heading_stats, chapter_descs, heading_descs)
    current_ch = nil
    heading_stats.each do |row|
      current_ch = print_heading_chapter(row[:ch], current_ch, chapter_descs)
      work = row[:missing] + row[:stale] + row[:drifted]
      $stdout.printf "  %-4s %-38s %6d %6d %6d %6d\n",
                     row[:hd], heading_descs[row[:hd]] || '?', row[:missing], row[:stale], row[:drifted], work
    end
  end

  def print_heading_chapter(chapter, current_chapter, chapter_descs)
    return current_chapter if chapter == current_chapter

    $stdout.puts "-- Chapter #{chapter}: #{chapter_descs[chapter] || '?'} --"
    chapter
  end

  def print_commodity_work_rows(context)
    work_rows = commodity_work_rows(context)

    $stdout.puts 'All Commodities Needing Work (ordered by item_id, producline_suffix)'
    $stdout.puts '=' * 120
    $stdout.printf "%-12s %-4s %-9s %-80s\n", 'Item ID', 'PLS', 'Reason', 'Description'
    $stdout.puts '-' * 120
    print_commodity_work_row_details(work_rows) if work_rows.any?
    $stdout.puts '-' * 120
    $stdout.puts "Total needing work: #{work_rows.size}"
  end

  def commodity_work_rows(context)
    expressions = context[:expressions]
    needing_work_dataset(context).select(
      context[:goods_nomenclatures_table][:goods_nomenclature_sid],
      context[:goods_nomenclatures_table][:goods_nomenclature_item_id],
      context[:goods_nomenclatures_table][:producline_suffix],
      Sequel.case(
        [[expressions[:unlabeled], 'missing'], [expressions[:stale], 'stale'], [expressions[:drifted], 'drifted']],
        'unknown',
      ).as(:reason),
    )
      .order(context[:goods_nomenclatures_table][:goods_nomenclature_item_id], context[:goods_nomenclatures_table][:producline_suffix])
      .all
  end

  def print_commodity_work_row_details(work_rows)
    descriptions = commodity_work_descriptions(work_rows)
    work_rows.each do |row|
      $stdout.printf "%-12s %-4s %-9s %-80s\n",
                     row[:goods_nomenclature_item_id], row[:producline_suffix], row[:reason], descriptions[row[:goods_nomenclature_sid]] || '?'
    end
  end

  def commodity_work_descriptions(work_rows)
    work_sids = work_rows.map { |row| row[:goods_nomenclature_sid] }
    GoodsNomenclature.actual
      .where(goods_nomenclature_sid: work_sids)
      .eager(:goods_nomenclature_descriptions)
      .all
      .to_h { |item| [item.goods_nomenclature_sid, item.description&.truncate(80) || '?'] }
  end
end
