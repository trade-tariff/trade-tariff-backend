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

namespace :search do
  desc 'Compare OpenSearch vs vector retrieval: overlap, latency, rank correlation. ' \
       'QUERIES=/path/to/queries.txt LIMIT=20 OUTPUT=tmp/retrieval_benchmark.csv'
  task benchmark_retrieval: :environment do
    queries = load_queries
    limit = ENV.fetch('LIMIT', '20').to_i
    output_path = ENV.fetch('OUTPUT', 'tmp/retrieval_benchmark.csv')

    puts "Queries: #{queries.size}"
    puts "Limit:   #{limit} results per method"
    puts "Output:  #{output_path}"
    puts

    embedding_service = EmbeddingService.new
    as_of = Time.zone.today

    all_rows = queries.map.with_index(1) do |query, i|
      print "  [#{i}/#{queries.size}] #{query.ljust(30)}"

      os_codes, os_ms = timed { opensearch_codes(query, as_of, limit) }
      vec_codes, vec_ms = timed { vector_codes(query, as_of, limit, embedding_service) }

      os_set = os_codes.to_set
      vec_set = vec_codes.to_set
      intersection = os_set & vec_set
      union = os_set | vec_set

      jaccard = union.empty? ? 0.0 : intersection.size.to_f / union.size
      overlap_at_k = os_codes.empty? ? 0.0 : intersection.size.to_f / os_codes.size

      # Rank correlation for shared items
      rank_corr = rank_correlation(os_codes, vec_codes, intersection)

      # Top-5 side-by-side for quick eyeballing
      os_top5 = os_codes.first(5).join(' ')
      vec_top5 = vec_codes.first(5).join(' ')

      puts "  OS=#{os_ms}ms  Vec=#{vec_ms}ms  J=#{fmt(jaccard)}  Overlap=#{intersection.size}/#{os_codes.size}"

      {
        query: query,
        opensearch_count: os_codes.size,
        vector_count: vec_codes.size,
        shared_count: intersection.size,
        jaccard: jaccard.round(4),
        overlap_at_k: overlap_at_k.round(4),
        rank_correlation: rank_corr&.round(4),
        opensearch_ms: os_ms,
        vector_ms: vec_ms,
        speedup: os_ms.zero? ? nil : (os_ms.to_f / [vec_ms, 1].max).round(2),
        opensearch_only: (os_set - vec_set).to_a.join(' '),
        vector_only: (vec_set - os_set).to_a.join(' '),
        opensearch_top5: os_top5,
        vector_top5: vec_top5,
      }
    end

    FileUtils.mkdir_p(File.dirname(output_path))
    write_csv(all_rows, output_path)

    puts
    print_summary(all_rows)

    puts "\nCSV written to #{output_path}"
  end
end

def load_queries
  if ENV['QUERIES']
    File.readlines(ENV['QUERIES']).map(&:strip).reject(&:empty?)
  else
    BENCHMARK_QUERIES
  end
end

def timed
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  result = yield
  ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).round(0).to_i
  [result, ms]
end

def opensearch_codes(query, as_of, limit)
  expanded = if AdminConfiguration.enabled?('expand_search_enabled')
               ExpandSearchQueryService.call(query).expanded_query
             else
               query
             end

  results = SearchLabels.with_labels do
    TradeTariffBackend.search_client.search(
      Search::GoodsNomenclatureQuery.new(
        query,
        as_of,
        expanded_query: expanded,
        pos_search: AdminConfiguration.enabled?('pos_search_enabled'),
        size: limit,
        noun_boost: AdminConfiguration.integer_value('pos_noun_boost'),
        qualifier_boost: AdminConfiguration.integer_value('pos_qualifier_boost'),
      ).query,
    )
  end

  (results.dig('hits', 'hits') || []).map { |h| h['_source']['goods_nomenclature_item_id'] }
end

def vector_codes(query, as_of, limit, embedding_service)
  query_embedding = embedding_service.embed(query)
  vector_literal = "'[#{query_embedding.join(',')}]'::vector"
  db = Sequel::Model.db

  db.transaction do
    db.run('SET LOCAL hnsw.ef_search = 100')

    db.fetch(<<~SQL, as_of: as_of, limit: limit).map { |r| r[:goods_nomenclature_item_id] }
      SELECT gn.goods_nomenclature_item_id
      FROM goods_nomenclature_self_texts st
      JOIN goods_nomenclatures gn
        ON gn.goods_nomenclature_sid = st.goods_nomenclature_sid
      WHERE st.search_embedding IS NOT NULL
        AND gn.producline_suffix = '80'
        AND gn.goods_nomenclature_item_id NOT IN (
          SELECT goods_nomenclature_item_id FROM hidden_goods_nomenclatures
        )
        AND (gn.validity_start_date IS NULL OR gn.validity_start_date <= :as_of)
        AND (gn.validity_end_date IS NULL OR gn.validity_end_date >= :as_of)
      ORDER BY st.search_embedding <=> #{vector_literal}
      LIMIT :limit
    SQL
  end
end

def rank_correlation(os_codes, vec_codes, intersection)
  return nil if intersection.size < 2

  shared = intersection.to_a
  os_ranks = shared.map { |c| os_codes.index(c) }
  vec_ranks = shared.map { |c| vec_codes.index(c) }

  # Spearman rank correlation
  n = shared.size
  d_squared_sum = os_ranks.zip(vec_ranks).sum { |a, b| (a - b)**2 }
  1.0 - (6.0 * d_squared_sum) / (n * (n**2 - 1))
end

def fmt(val)
  sprintf('%.2f', val)
end

def write_csv(rows, path)
  CSV.open(path, 'w') do |csv|
    csv << rows.first.keys
    rows.each { |row| csv << row.values }
  end
end

def print_summary(rows)
  os_latencies = rows.map { |r| r[:opensearch_ms] }.sort
  vec_latencies = rows.map { |r| r[:vector_ms] }.sort
  jaccards = rows.map { |r| r[:jaccard] }
  overlaps = rows.map { |r| r[:overlap_at_k] }
  correlations = rows.map { |r| r[:rank_correlation] }.compact

  puts '=' * 70
  puts 'SUMMARY'
  puts '=' * 70

  puts
  puts 'Latency (ms)'
  puts sprintf('  %-12s %8s %8s %8s %8s', '', 'P50', 'P95', 'Mean', 'Max')
  puts sprintf('  %-12s %8d %8d %8d %8d', 'OpenSearch', percentile(os_latencies, 50), percentile(os_latencies, 95), mean(os_latencies), os_latencies.max)
  puts sprintf('  %-12s %8d %8d %8d %8d', 'Vector', percentile(vec_latencies, 50), percentile(vec_latencies, 95), mean(vec_latencies), vec_latencies.max)

  puts
  puts 'Result overlap'
  puts sprintf('  Mean Jaccard:     %s', fmt(mean(jaccards)))
  puts sprintf('  Mean Overlap@K:   %s', fmt(mean(overlaps)))
  puts sprintf('  Mean Rank Corr:   %s', correlations.any? ? fmt(mean(correlations)) : 'N/A')

  puts
  puts 'Coverage'
  os_zero = rows.count { |r| r[:opensearch_count].zero? }
  vec_zero = rows.count { |r| r[:vector_count].zero? }
  puts sprintf('  OpenSearch empty:  %d/%d queries', os_zero, rows.size)
  puts sprintf('  Vector empty:      %d/%d queries', vec_zero, rows.size)
end

def percentile(sorted, pct)
  return 0 if sorted.empty?

  k = (pct / 100.0 * (sorted.size - 1)).round
  sorted[k]
end

def mean(values)
  return 0 if values.empty?

  values.sum.to_f / values.size
end
