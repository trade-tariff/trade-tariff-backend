class SelfTextCoverageReporter
  def self.call
    new.call
  end

  def call
    TimeMachine.now { print_stats(coverage_stats) }
  end

private

  def coverage_stats
    total_gn = GoodsNomenclature.actual.non_hidden.count - Chapter.actual.count
    total_self_texts = GoodsNomenclatureSelfText.count
    missing = total_gn - total_self_texts
    stale = GoodsNomenclatureSelfText.where(stale: true).count

    {
      total_gn:,
      total_self_texts:,
      missing:,
      stale:,
      needing_work: missing + stale,
      coverage: total_gn.positive? ? (total_self_texts * 100.0 / total_gn).round(2) : 0,
      by_type: GoodsNomenclatureSelfText.group_and_count(:generation_type).order(:generation_type).all,
    }
  end

  def print_stats(stats)
    $stdout.puts 'Self-Text Coverage Statistics'
    $stdout.puts '-' * 30
    $stdout.puts "Total GN (excl. chapters): #{stats[:total_gn]}"
    $stdout.puts "With self-text:            #{stats[:total_self_texts]}"
    $stdout.puts "Missing:                   #{stats[:missing]}"
    $stdout.puts "Coverage:                  #{stats[:coverage]}%"
    $stdout.puts "Stale:                     #{stats[:stale]}"
    $stdout.puts "Needing work:              #{stats[:needing_work]}"
    $stdout.puts
    $stdout.puts 'By generation type:'
    stats[:by_type].each { |row| $stdout.puts "  #{row[:generation_type]}: #{row[:count]}" }
  end
end
