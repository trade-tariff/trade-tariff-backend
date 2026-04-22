class PrewarmCommoditiesWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: true

  DEFAULT_LOOKBACK_HOURS = 24
  DEFAULT_LIMIT = 1000
  QUERY_POLL_INTERVAL_SECONDS = 1
  QUERY_MAX_POLLS = 60

  def perform(log_group_name = ENV['SEARCH_LOG_GROUP_NAME'])
    preconfigured_ids = preconfigured_goods_nomenclature_item_ids
    most_requested_ids = if log_group_name.present?
                           most_requested_goods_nomenclature_item_ids(
                             log_group_name:,
                             lookback_hours: DEFAULT_LOOKBACK_HOURS,
                             limit: DEFAULT_LIMIT,
                           )
                         else
                           logger.warn 'PrewarmCommoditiesWorker running with preconfigured ids only: SEARCH_LOG_GROUP_NAME is not set'
                           []
                         end
    ids = (preconfigured_ids + most_requested_ids).uniq

    if ids.empty?
      logger.info 'PrewarmCommoditiesWorker found no commodity ids to prewarm'
      return
    end

    warmed = 0
    skipped = 0
    failed = 0

    TimeMachine.now do
      actual_date = Date.current
      commodities_by_item_id = Commodity.actual
                                      .by_codes(ids)
                                      .all
                                      .each_with_object({}) do |commodity, memo|
        memo[commodity.goods_nomenclature_item_id] = commodity
      end

      ids.each do |goods_nomenclature_item_id|
        commodity = commodities_by_item_id[goods_nomenclature_item_id]
        if commodity.nil?
          skipped += 1
          next
        end

        CachedCommodityService.new(commodity, actual_date).call
        warmed += 1
      rescue StandardError => e
        failed += 1
        logger.info(
          "PrewarmCommoditiesWorker failed for #{goods_nomenclature_item_id}: #{e.class} - #{e.message}",
        )
      end
    end

    logger.info(
      "PrewarmCommoditiesWorker complete: requested=#{ids.size} warmed=#{warmed} skipped=#{skipped} failed=#{failed}",
    )
  end

  def self.client
    @client ||= Aws::CloudWatchLogs::Client.new
  end

  private

  def preconfigured_goods_nomenclature_item_ids
    ENV.fetch('PREWARM_COMMODITY_IDS', '')
       .split(',')
       .map(&:strip)
       .reject(&:empty?)
       .uniq
  end

  def most_requested_goods_nomenclature_item_ids(log_group_name:, lookback_hours:, limit:)
    query_id = self.class.client.start_query(
      log_group_name:,
      start_time: (Time.current - lookback_hours.hours).to_i,
      end_time: Time.current.to_i,
      query_string: cloudwatch_query(limit),
    ).query_id

    results = await_query_results(query_id)

    results.filter_map do |row|
      row.to_h { |field| [field.field, field.value] }['goods_nomenclature_item_id']
    end.uniq
  rescue StandardError => e
    logger.error("PrewarmCommoditiesWorker CloudWatch query failed: #{e.class} - #{e.message}")
    []
  end

  def await_query_results(query_id)
    QUERY_MAX_POLLS.times do
      response = self.class.client.get_query_results(query_id:)
      return response.results if response.status == 'Complete'

      raise "CloudWatch query #{response.status}" if %w[Failed Cancelled Timeout Unknown].include?(response.status)

      sleep QUERY_POLL_INTERVAL_SECONDS
    end

    raise 'CloudWatch query timed out while polling'
  end

  def cloudwatch_query(limit)
    <<~QUERY
      fields @timestamp, goods_nomenclature_item_id, event, service
      | filter service = "search" and event = "result_selected" and goods_nomenclature_class = "Commodity" and ispresent(goods_nomenclature_item_id)
      | stats count(*) as selections by goods_nomenclature_item_id
      | sort selections desc
      | limit #{limit}
    QUERY
  end
end
