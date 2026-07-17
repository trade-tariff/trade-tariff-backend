class SelfTextValidationReporter
  def self.call(threshold:, flag_below:)
    new(threshold:, flag_below:).call
  end

  def initialize(threshold:, flag_below:)
    @threshold = threshold
    @flag_below = flag_below
  end

  def call
    validate_similarity
    validate_coherence
  end

private

  attr_reader :threshold, :flag_below

  def validate_similarity
    print_heading('PART A: EU Reference Comparison (similarity_score)')
    pairs = GoodsNomenclatureSelfText.exclude(similarity_score: nil).order(:similarity_score).all
    return $stdout.puts 'No similarity scores found. Run self_texts:score first.' if pairs.empty?

    similarities = pairs.map(&:similarity_score)
    print_score_summary('pairs', similarities)
    print_low_similarity_pairs(pairs)
    $stdout.puts "Below threshold: #{count_below_threshold(similarities)} records" if flag_below
  end

  def validate_coherence
    $stdout.puts
    print_heading('PART B: Coherence Check (no EU reference)')
    gap_nodes = GoodsNomenclatureSelfText.exclude(coherence_score: nil).order(:coherence_score).all
    return $stdout.puts 'No coherence scores found. Run self_texts:score first.' if gap_nodes.empty?

    scores = gap_nodes.map(&:coherence_score)
    print_score_summary('gap nodes', scores, score_name: 'coherence')
    print_low_coherence_nodes(gap_nodes)
  end

  def print_heading(heading)
    $stdout.puts '=' * 80
    $stdout.puts heading
    $stdout.puts '=' * 80
  end

  def print_score_summary(label, scores, score_name: 'similarity')
    $stdout.puts "Total #{label}: #{scores.size}"
    $stdout.puts "Mean #{score_name}: #{(scores.sum / scores.size).round(4)}"
    $stdout.puts "Median: #{percentile(scores, 50).round(4)}"
    $stdout.puts "P5: #{percentile(scores, 5).round(4)}"
    $stdout.puts "P95: #{percentile(scores, 95).round(4)}"
    $stdout.puts "Below #{threshold}: #{count_below_threshold(scores)}"
    $stdout.puts
  end

  def count_below_threshold(scores)
    scores.count { |score| score < threshold }
  end

  def print_low_similarity_pairs(pairs)
    $stdout.puts 'Bottom 20 lowest-similarity pairs:'
    $stdout.puts '-' * 80
    pairs.first(20).each_with_index do |row, index|
      $stdout.puts "#{index + 1}. [#{row.goods_nomenclature_item_id}] similarity=#{row.similarity_score.round(4)}"
      $stdout.puts "   Generated: #{row.self_text&.truncate(120)}"
      $stdout.puts "   EU:        #{row.eu_self_text&.truncate(120)}"
      $stdout.puts
    end
  end

  def print_low_coherence_nodes(gap_nodes)
    $stdout.puts 'Bottom 20 lowest-coherence gap nodes:'
    $stdout.puts '-' * 80
    gap_nodes.first(20).each_with_index do |row, index|
      $stdout.puts "#{index + 1}. [#{row.goods_nomenclature_item_id}] coherence=#{row.coherence_score.round(4)}"
      $stdout.puts "   Generated: #{row.self_text&.truncate(120)}"
      $stdout.puts
    end
  end

  def percentile(values, pct)
    return 0.0 if values.empty?

    sorted = values.sort
    percentile_index = (pct / 100.0) * (sorted.size - 1)
    floor = percentile_index.floor
    ceiling = percentile_index.ceil
    return sorted[floor] if floor == ceiling

    sorted[floor] + (percentile_index - floor) * (sorted[ceiling] - sorted[floor])
  end
end
