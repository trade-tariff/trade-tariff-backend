module EvaluationRakeTasks
module_function

  # Spike: compares evaluation runs as a markdown table, for example the same
  # question_model on OpenAI and on Bedrock.
  #
  #   RUN_IDS=12,13,14 bundle exec rake tariff:evaluation:compare_runs
  def compare_runs
    abort 'RUN_IDS is required, for example RUN_IDS=12,13' if ENV['RUN_IDS'].blank?

    rows = Evaluation::RunComparison.call(ENV['RUN_IDS'].split(',').map(&:strip))

    puts '| Run | Question model | Provider | Results | Errors | Top-1 % | Top-5 % | p50 latency (s) | p95 latency (s) | Provider calls | Cost / 1,000 (USD) | Cost / 1,000 with gb uplift (USD) |'
    puts '| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |'
    rows.each do |row|
      puts "| #{row.to_h.values.join(' | ')} |"
    end
    puts
    puts 'Top-1, top-5 and latency exclude errored results. Cost includes them, because errored searches still spend tokens.'
    puts "The gb uplift adds OpenAI's 10% regional processing charge to OpenAI runs of #{Evaluation::RunComparison::GB_UPLIFT_MODELS.join(', ')}."
    puts 'It applies to the whole search cost, so it slightly overstates the small expansion, duplicate-guard and embedding costs.'
  rescue ArgumentError => e
    abort e.message
  end
end

desc 'Compare evaluation runs: quality, p50/p95 latency and cost per 1,000 searches (RUN_IDS=1,2,3)'
task 'tariff:evaluation:compare_runs' => :environment do
  EvaluationRakeTasks.compare_runs
end
