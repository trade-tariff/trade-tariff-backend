class ImportPublicAtarRulingsWorker
  include Sidekiq::Worker

  sidekiq_options queue: :within_1_day, retry: 3

  def perform(options = {})
    unless TradeTariffBackend.service == 'uk'
      Rails.logger.info('Skipping public ATAR import outside UK service mode')
      return
    end

    result = TariffKnowledge::PublicAtarRulingImporter.call(**options.symbolize_keys)
    Rails.logger.info("Public ATAR import complete: #{result.seen_count} seen, #{result.created_count} created, #{result.updated_count} updated, #{result.failed_count} failed")
  end
end
