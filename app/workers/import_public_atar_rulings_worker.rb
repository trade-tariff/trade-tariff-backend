class ImportPublicAtarRulingsWorker
  include Sidekiq::Worker

  sidekiq_options queue: :within_1_day, retry: 3

  def perform(options = {})
    unless TradeTariffBackend.service == 'uk'
      Rails.logger.info('Skipping public ATAR import outside UK service mode')
      return
    end

    importer_options = options.symbolize_keys.merge(generate_derived_facts: true)

    result = TariffKnowledge::PublicAtarRulingImporter.call(**importer_options)
    refreshed_sids = TariffKnowledge::PublicAtarSearchRefresh.call(result.refresh_goods_nomenclature_item_ids)
    Rails.logger.info("Public ATAR import complete: #{result.seen_count} seen, #{result.created_count} created, #{result.updated_count} updated, #{result.failed_count} failed")
    Rails.logger.info("Public ATAR fact generation complete: #{result.derived_facts_generated_count} generated, #{result.derived_facts_empty_count} empty, #{result.derived_facts_failed_count} failed, #{result.derived_facts_skipped_count} skipped")
    Rails.logger.info("Public ATAR search refresh complete: #{refreshed_sids.size} goods nomenclatures refreshed or queued")
  end
end
