class SelfTextGapReporter
  def self.call(chapter_code)
    new(chapter_code).call
  end

  def initialize(chapter_code)
    @chapter_code = chapter_code
  end

  def call
    TimeMachine.now do
      context = gap_context
      print_chapter_summary(context)
      print_heading_details(context)
    end
  end

private

  attr_reader :chapter_code

  def gap_context
    goods_nomenclatures_table = Sequel[:goods_nomenclatures]
    self_texts_table = Sequel[:goods_nomenclature_self_texts]
    base = base_dataset(goods_nomenclatures_table, self_texts_table)
    needing_work = base.where(Sequel.expr(self_texts_table[:goods_nomenclature_sid] => nil) | Sequel.expr(self_texts_table[:stale] => true))
    chapter_stats = chapter_stats(base, goods_nomenclatures_table, self_texts_table)

    { goods_nomenclatures_table:, self_texts_table:, needing_work:, chapter_stats:, chapter_descs: chapter_descriptions }
  end

  def base_dataset(goods_nomenclatures_table, self_texts_table)
    base = GoodsNomenclature.actual
      .non_hidden
      .exclude(goods_nomenclatures_table[:goods_nomenclature_item_id] => Chapter.actual.select(:goods_nomenclature_item_id))
      .left_join(:goods_nomenclature_self_texts, { self_texts_table[:goods_nomenclature_sid] => goods_nomenclatures_table[:goods_nomenclature_sid] })

    return base unless chapter_code

    base.where(Sequel.like(goods_nomenclatures_table[:goods_nomenclature_item_id], "#{chapter_code.ljust(2, '0')}%"))
  end

  def chapter_stats(base, goods_nomenclatures_table, self_texts_table)
    base
      .select_group(Sequel.function(:substr, goods_nomenclatures_table[:goods_nomenclature_item_id], 1, 2).as(:ch))
      .select_append { count(Sequel.lit('*')).as(total) }
      .select_append { count(Sequel.case([[{ self_texts_table[:goods_nomenclature_sid] => nil }, 1]], nil)).as(missing) }
      .select_append { count(Sequel.case([[{ self_texts_table[:stale] => true }, 1]], nil)).as(stale) }
      .order(:ch)
      .all
  end

  def chapter_descriptions
    Chapter.actual
      .eager(:goods_nomenclature_descriptions)
      .all
      .to_h { |chapter| [chapter.goods_nomenclature_item_id.first(2), chapter.description&.truncate(50)] }
  end

  def print_chapter_summary(context)
    $stdout.puts 'Self-Text Gaps and Stale Records by Chapter'
    $stdout.puts '=' * 100
    $stdout.printf "%-4s %-50s %6s %6s %6s %6s %7s\n", 'Ch', 'Description', 'Total', 'Miss', 'Stale', 'Work', 'Cov %'
    $stdout.puts '-' * 100
    context[:chapter_stats].each { |row| print_chapter_row(row, context[:chapter_descs]) }
    print_chapter_total(context[:chapter_stats])
  end

  def print_chapter_row(row, chapter_descs)
    total = row[:total]
    work = row[:missing] + row[:stale]
    coverage = total.positive? ? ((total - row[:missing]) * 100.0 / total).round(1) : 0
    $stdout.printf "%-4s %-50s %6d %6d %6d %6d %6.1f%%\n",
                   row[:ch], chapter_descs[row[:ch]] || '?', total, row[:missing], row[:stale], work, coverage
  end

  def print_chapter_total(chapter_stats)
    totals = chapter_totals(chapter_stats)
    $stdout.puts '-' * 100
    $stdout.printf "%-55s %6d %6d %6d %6d %6.1f%%\n",
                   'TOTAL', totals[:total], totals[:missing], totals[:stale], totals[:work], totals[:coverage]
    $stdout.puts
  end

  def chapter_totals(chapter_stats)
    total = chapter_stats.sum { |row| row[:total] }
    missing = chapter_stats.sum { |row| row[:missing] }
    stale = chapter_stats.sum { |row| row[:stale] }
    work = missing + stale
    coverage = total.positive? ? ((total - missing) * 100.0 / total).round(1) : 0

    { total:, missing:, stale:, work:, coverage: }
  end

  def print_heading_details(context)
    if gap_chapters(context[:chapter_stats]).any?
      print_headings(context)
    else
      $stdout.puts 'No gaps found - full coverage, nothing stale!'
    end
  end

  def gap_chapters(chapter_stats)
    chapter_stats.select { |row| row[:missing].positive? || row[:stale].positive? }.map { |row| row[:ch] }
  end

  def print_headings(context)
    heading_stats = heading_stats(context)
    heading_descs = heading_descriptions
    $stdout.puts 'Self-Texts Needing Work by Heading'
    $stdout.puts '=' * 90
    $stdout.printf "%-6s %-50s %6s %6s %6s\n", 'Head', 'Description', 'Miss', 'Stale', 'Work'
    $stdout.puts '-' * 90
    print_heading_rows(heading_stats, context[:chapter_descs], heading_descs)
    $stdout.puts
    print_work_rows(context)
  end

  def heading_stats(context)
    goods_nomenclatures_table = context[:goods_nomenclatures_table]
    self_texts_table = context[:self_texts_table]
    context[:needing_work].select_group(
      Sequel.function(:substr, goods_nomenclatures_table[:goods_nomenclature_item_id], 1, 2).as(:ch),
      Sequel.function(:substr, goods_nomenclatures_table[:goods_nomenclature_item_id], 1, 4).as(:hd),
    )
      .select_append { count(Sequel.case([[{ self_texts_table[:goods_nomenclature_sid] => nil }, 1]], nil)).as(missing) }
      .select_append { count(Sequel.case([[{ self_texts_table[:stale] => true }, 1]], nil)).as(stale) }
      .order(:ch, :hd)
      .all
  end

  def heading_descriptions
    Heading.actual
      .eager(:goods_nomenclature_descriptions)
      .all
      .to_h { |heading| [heading.goods_nomenclature_item_id.first(4), heading.description&.truncate(50)] }
  end

  def print_heading_rows(heading_stats, chapter_descs, heading_descs)
    current_chapter = nil
    heading_stats.each do |row|
      current_chapter = print_heading_chapter(row[:ch], current_chapter, chapter_descs)
      work = row[:missing] + row[:stale]
      $stdout.printf "  %-4s %-48s %6d %6d %6d\n", row[:hd], heading_descs[row[:hd]] || '?', row[:missing], row[:stale], work
    end
  end

  def print_heading_chapter(chapter, current_chapter, chapter_descs)
    return current_chapter if chapter == current_chapter

    $stdout.puts "-- Chapter #{chapter}: #{chapter_descs[chapter] || '?'} --"
    chapter
  end

  def print_work_rows(context)
    work_rows = work_rows(context)
    $stdout.puts 'All Goods Nomenclatures Needing Work (ordered by item_id, producline_suffix)'
    $stdout.puts '=' * 110
    $stdout.printf "%-12s %-4s %-7s %-80s\n", 'Item ID', 'PLS', 'Reason', 'Description'
    $stdout.puts '-' * 110
    print_work_row_details(work_rows) if work_rows.any?
    $stdout.puts '-' * 110
    $stdout.puts "Total needing work: #{work_rows.size}"
  end

  def work_rows(context)
    goods_nomenclatures_table = context[:goods_nomenclatures_table]
    self_texts_table = context[:self_texts_table]
    context[:needing_work].select(
      goods_nomenclatures_table[:goods_nomenclature_sid],
      goods_nomenclatures_table[:goods_nomenclature_item_id],
      goods_nomenclatures_table[:producline_suffix],
      Sequel.case([[{ self_texts_table[:goods_nomenclature_sid] => nil }, 'missing']], 'stale').as(:reason),
    )
      .order(goods_nomenclatures_table[:goods_nomenclature_item_id], goods_nomenclatures_table[:producline_suffix])
      .all
  end

  def print_work_row_details(work_rows)
    descriptions = work_descriptions(work_rows)
    work_rows.each do |row|
      $stdout.printf "%-12s %-4s %-7s %-80s\n",
                     row[:goods_nomenclature_item_id], row[:producline_suffix], row[:reason], descriptions[row[:goods_nomenclature_sid]] || '?'
    end
  end

  def work_descriptions(work_rows)
    work_sids = work_rows.map { |row| row[:goods_nomenclature_sid] }
    GoodsNomenclature.actual
      .where(goods_nomenclature_sid: work_sids)
      .eager(:goods_nomenclature_descriptions)
      .all
      .to_h { |item| [item.goods_nomenclature_sid, item.description&.truncate(80) || '?'] }
  end
end
