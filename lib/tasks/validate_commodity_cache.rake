namespace :commodity_cache do
  desc <<~DESC
    Validate that CachedCommodityService v4 (cache-once, filter-at-read-time)
    produces identical responses to the old code path (filter-then-serialize)
    for every declarable commodity and a set of representative countries.

    This proves that removing geographical_area_id from the cache key and
    applying country filtering at read time is behaviourally equivalent.

    Usage:
      bundle exec rake commodity_cache:validate
      bundle exec rake commodity_cache:validate COUNTRIES=RO,DE,CN
      bundle exec rake commodity_cache:validate LIMIT=100
      bundle exec rake commodity_cache:validate CHAPTER=02
      bundle exec rake commodity_cache:validate SID=12345
  DESC
  task validate: :environment do
    countries = (ENV['COUNTRIES'] || 'RO,DE,CN,US,JP,AU,BR,KR,IN,ZA').split(',')
    limit = ENV['LIMIT']&.to_i
    chapter = ENV['CHAPTER']
    sid = ENV['SID']&.to_i

    puts 'Commodity cache v4 validation'
    puts '=============================='
    puts "Countries: #{countries.join(', ')}"
    puts "Limit: #{limit || 'all'}"
    puts "Chapter: #{chapter || 'all'}"
    puts "SID: #{sid || 'all'}"
    puts

    failures = []
    total = 0
    skipped = 0

    TimeMachine.now do
      commodities = Commodity.actual.non_hidden
      commodities = commodities.where(goods_nomenclature_sid: sid) if sid
      commodities = commodities.where(Sequel.like(:goods_nomenclature_item_id, "#{chapter}%")) if chapter
      commodities = commodities.limit(limit) if limit
      commodity_ids = commodities.select_map(:goods_nomenclature_sid)

      puts "Validating #{commodity_ids.size} commodities..."
      puts

      commodity_ids.each_with_index do |commodity_sid, idx|
        commodity = load_commodity(commodity_sid)

        if commodity.nil?
          skipped += 1
          next
        end

        total += 1

        # Test without country filter
        result = validate_commodity(commodity, {})
        if result
          failures << result
          warn "  FAIL [#{commodity.goods_nomenclature_item_id}] no filter: #{result[:field]}"
        end

        # Test with each country filter
        countries.each do |country_id|
          result = validate_commodity(commodity, geographical_area_id: country_id)
          if result
            failures << result
            warn "  FAIL [#{commodity.goods_nomenclature_item_id}] #{country_id}: #{result[:field]}"
          end
        end

        if ((idx + 1) % 100).zero?
          puts "  Progress: #{idx + 1}/#{commodity_ids.size} (#{failures.size} failures)"
        end

        # Clear Rails cache between commodities to avoid cross-contamination
        Rails.cache.delete_matched('_commodity-v*')
      end
    end

    puts
    puts 'Results'
    puts '======='
    puts "Commodities tested: #{total}"
    puts "Commodities skipped: #{skipped}"
    puts "Filter combinations tested: #{total * (1 + countries.size)}"
    puts "Failures: #{failures.size}"

    puts

    if failures.any?
      puts 'Failure details (first 50):'
      failures.first(50).each do |f|
        puts "  #{f[:item_id]} | #{f[:filter]} | #{f[:field]}: expected #{f[:expected].inspect}, got #{f[:actual].inspect}"
      end
      exit 1
    else
      puts 'All validations passed.'
    end
  end

  desc 'Clear all commodity cache entries'
  task clear: :environment do
    puts 'Clearing commodity cache entries...'
    Rails.cache.delete_matched('_commodity-v*')
    puts 'Done.'
  end
end

def load_commodity(commodity_sid)
  Commodity
    .actual
    .where(goods_nomenclature_sid: commodity_sid)
    .eager(
      ancestors: {
        measures: CachedCommodityService::MEASURES_EAGER_LOAD_GRAPH,
        goods_nomenclature_descriptions: {},
      },
      measures: CachedCommodityService::MEASURES_EAGER_LOAD_GRAPH,
    )
    .take
rescue StandardError => e
  warn "  ERROR loading commodity #{commodity_sid}: #{e.message}"
  nil
end

def validate_commodity(commodity, filters)
  serializer_options = {
    is_collection: false,
    include: CachedCommodityService::DEFAULT_INCLUDES,
  }

  # Old path: filter measures first, then serialize
  measures = MeasureCollection.new(commodity.applicable_measures, filters).filter
  presenter = Api::V2::Commodities::CommodityPresenter.new(commodity, measures)
  reference = Api::V2::Commodities::CommoditySerializer.new(presenter, serializer_options).serializable_hash

  # New path: use CachedCommodityService (cache unfiltered, filter at read time)
  Rails.cache.delete_matched('_commodity-v*')
  params = ActionController::Parameters.new(filters).permit!
  result = CachedCommodityService.new(commodity, Time.zone.today, params).call

  filter_label = filters[:geographical_area_id] || 'none'
  item_id = commodity.goods_nomenclature_item_id

  # Compare import measure sids
  result_import_sids = extract_import_sids(result).sort
  ref_import_sids = extract_import_sids(reference).sort
  unless result_import_sids == ref_import_sids
    return { item_id: item_id,
             filter: filter_label,
             field: 'import_measure_sids',
             expected: ref_import_sids,
             actual: result_import_sids }
  end

  # Compare export measure sids
  result_export_sids = extract_export_sids(result).sort
  ref_export_sids = extract_export_sids(reference).sort
  unless result_export_sids == ref_export_sids
    return { item_id: item_id,
             filter: filter_label,
             field: 'export_measure_sids',
             expected: ref_export_sids,
             actual: result_export_sids }
  end

  # Compare basic_duty_rate
  result_bdr = result[:data][:attributes][:basic_duty_rate]
  ref_bdr = reference[:data][:attributes][:basic_duty_rate]
  unless result_bdr == ref_bdr
    return { item_id: item_id,
             filter: filter_label,
             field: 'basic_duty_rate',
             expected: ref_bdr,
             actual: result_bdr }
  end

  # Compare duty_calculator meta
  result_dc = result[:data][:meta][:duty_calculator]
  ref_dc = reference[:data][:meta][:duty_calculator]
  unless result_dc == ref_dc
    diff_key = (ref_dc.keys + result_dc.keys).uniq.find { |k| result_dc[k] != ref_dc[k] }
    return { item_id: item_id,
             filter: filter_label,
             field: "duty_calculator.#{diff_key}",
             expected: ref_dc[diff_key],
             actual: result_dc[diff_key] }
  end

  # Compare import_trade_summary
  result_its = result[:included]&.find { |e| e[:type].to_s == 'import_trade_summary' }
  ref_its = reference[:included]&.find { |e| e[:type].to_s == 'import_trade_summary' }
  if result_its && ref_its && result_its[:attributes] != ref_its[:attributes]
    diff_key = ref_its[:attributes].keys.find { |k| result_its[:attributes][k] != ref_its[:attributes][k] }
    return { item_id: item_id,
             filter: filter_label,
             field: "import_trade_summary.#{diff_key}",
             expected: ref_its[:attributes][diff_key],
             actual: result_its[:attributes][diff_key] }
  end

  nil
end

def extract_import_sids(hash)
  hash[:data][:relationships][:import_measures][:data].map { |r| r[:id].to_s }
end

def extract_export_sids(hash)
  hash[:data][:relationships][:export_measures][:data].map { |r| r[:id].to_s }
end
