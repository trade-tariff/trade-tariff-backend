require 'csv'

BENCHMARK_QUERIES = [
  # Single-word common goods
  'laptop',
  'shoes',
  'wine',
  'cheese',
  'bicycle',
  'candles',
  # Colloquial UK terms
  'trainers',
  'wellies',
  'hoodie',
  'fairy lights',
  'sellotape',
  # Multi-word descriptive
  'horse meat',
  'cotton t-shirt',
  'leather handbag',
  'wooden furniture',
  'steel pipes',
  # Technical/specific
  'polyethylene granules',
  'lithium-ion batteries',
  'hydraulic cylinders',
  'capacitors',
  # Ambiguous
  'apple',
  'bass',
  'crane',
  'chips',
  # Food/agriculture
  'fresh salmon',
  'organic coffee beans',
  'frozen chicken wings',
  # Consumer goods - longer queries
  'car parts',
  'phone cases',
  'dog food',
  'baby clothes',
  'solar panels',
].freeze

CANDIDATE_MODELS = %w[
  gpt-4.1-mini-2025-04-14
  gpt-4.1-nano-2025-04-14
  gpt-4o-mini
].freeze

namespace :search do
  desc 'Benchmark query expansion models: latency + expanded query comparison. ' \
       'MODELS=model1,model2 QUERIES=/path/to/queries.txt OUTPUT=tmp/file.csv'
  task benchmark_expand: :environment do
    models = benchmark_models
    queries = benchmark_queries
    output_path = ENV.fetch('OUTPUT', 'tmp/expand_benchmark.csv')

    puts "Models:  #{models.map { |m| model_label(m) }.join(', ')}"
    puts "Queries: #{queries.size}"
    puts "Output:  #{output_path}"
    puts

    context_template = benchmark_expand_context
    abort 'No expand_query_context in AdminConfiguration. Run admin_configurations:seed.' if context_template.blank?

    client = OpenaiClient.new
    all_results = {}

    models.each do |model|
      puts model_label(model)
      puts '-' * 70
      all_results[model] = expand_all(client, context_template, model, queries)
      puts
    end

    FileUtils.mkdir_p(File.dirname(output_path))
    write_comparison_csv(models, all_results, queries, output_path)
    print_summary(models, all_results, queries)

    puts "CSV written to #{output_path}"
  end
end

def benchmark_models
  if ENV['MODELS']
    ENV['MODELS'].split(',').map(&:strip)
  else
    baseline = AdminConfiguration.option_value('expand_model')
    ([baseline] + CANDIDATE_MODELS).uniq
  end
end

def benchmark_queries
  if ENV['QUERIES'] && File.exist?(ENV['QUERIES'])
    File.readlines(ENV['QUERIES']).map(&:strip).reject(&:blank?)
  else
    BENCHMARK_QUERIES
  end
end

def benchmark_expand_context
  config = AdminConfiguration.classification.by_name('expand_query_context')
  config&.value.to_s.presence
end

def model_label(key) # rubocop:disable Rails/Delegate
  AdminConfigurationSeeder.model_label(key)
end

def expand_all(client, context_template, model, queries)
  results = {}

  queries.each_with_index do |query, i|
    context = context_template.gsub('%{search_query}', query)
    expanded = nil
    error = nil

    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    begin
      response = client.call(context, model: model)

      if response.is_a?(Hash) && response['expanded_query'].present?
        expanded = response['expanded_query']
      else
        error = "unexpected: #{response.to_s[0..100]}"
      end
    rescue StandardError => e
      error = "#{e.class}: #{e.message}"
    end
    latency_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000

    results[query] = { expanded:, latency_ms:, error: }

    status = error ? "ERROR #{error[0..50]}" : "#{latency_ms.round(0)}ms"
    preview = expanded ? " -> #{expanded[0..70]}" : ''
    puts "  [#{i + 1}/#{queries.size}] #{query.ljust(28)} #{status}#{preview}"
  end

  results
end

# One row per query, columns for each model's expansion and latency.
# Easy to compare side by side in a spreadsheet.
def write_comparison_csv(models, all_results, queries, path)
  headers = %w[query]
  models.each do |model|
    short = model_label(model)
    headers << "#{short} expansion"
    headers << "#{short} ms"
  end

  CSV.open(path, 'w') do |csv|
    csv << headers

    queries.each do |query|
      row = [query]
      models.each do |model|
        r = all_results[model][query]
        row << (r[:error] || r[:expanded])
        row << r[:latency_ms]&.round(0)
      end
      csv << row
    end
  end
end

def print_summary(models, all_results, queries)
  puts
  puts '=' * 90
  puts 'LATENCY SUMMARY'
  puts '=' * 90

  model_stats = models.map do |model|
    latencies = queries.filter_map { |q|
      r = all_results[model][q]
      r[:latency_ms] unless r[:error]
    }.sort
    errors = queries.count { |q| all_results[model][q][:error] }

    { model:, latencies:, errors: }
  end

  baseline_mean = model_stats.first[:latencies].then { |l| l.any? ? l.sum / l.size : 0 }

  model_stats.each do |stats|
    latencies = stats[:latencies]
    next if latencies.empty?

    mean = latencies.sum / latencies.size
    speedup = baseline_mean.positive? ? baseline_mean / mean : 0

    puts
    label = model_label(stats[:model])
    label += ' (baseline)' if stats[:model] == models.first
    puts label
    puts '-' * 70
    puts "  P50:    #{percentile(latencies, 50).round(0)}ms"
    puts "  P95:    #{percentile(latencies, 95).round(0)}ms"
    puts "  Mean:   #{mean.round(0)}ms"
    puts "  Min:    #{latencies.first.round(0)}ms"
    puts "  Max:    #{latencies.last.round(0)}ms"
    puts "  Errors: #{stats[:errors]}" if stats[:errors].positive?
    puts "  Speedup: #{speedup.round(1)}x vs baseline" unless stats[:model] == models.first
  end

  puts
  puts '=' * 90
end

def percentile(sorted_values, pct)
  return 0.0 if sorted_values.empty?

  k = (pct / 100.0) * (sorted_values.size - 1)
  f = k.floor
  c = k.ceil

  return sorted_values[f] if f == c

  sorted_values[f] + (k - f) * (sorted_values[c] - sorted_values[f])
end
