class RefreshChiefCdsGuidanceWorker
  include Sidekiq::Worker

  sidekiq_options retry: false

  def perform
    if using_fallback?
      logger.info 'Using fallback Chief CDS Guidance'

      TradeTariffBackend.chief_cds_guidance = ChiefCdsGuidance.load_fallback

      SlackNotifierService.call('Chief CDS Guidance has not been hot refreshed and fallback has been used.')
    elsif guidance_changed?
      logger.info 'Refreshing Chief CDS Guidance'

      new_guidance.guidance_last_updated_at = Time.zone.now unless using_fallback?

      TradeTariffBackend.chief_cds_guidance = new_guidance if new_guidance.present?

      logger.info "Finished refreshing Chief CDS Guidance #{new_guidance.guidance_last_updated_at}"

      notify_slack
    else
      logger.info 'No change in Chief CDS Guidance'
    end
  end

  private

  def notify_slack
    GuidanceChangeNotificationService.new(
      new_guidance.guidance,
      existing_guidance.guidance,
    ).call
  end

  def new_guidance
    @new_guidance ||= ChiefCdsGuidance.load_latest ||
      TradeTariffBackend.chief_cds_guidance ||
      ChiefCdsGuidance.load_fallback
  end

  def existing_guidance
    @existing_guidance ||= TradeTariffBackend.chief_cds_guidance
  end

  def guidance_changed?
    new_guidance.present? && existing_guidance.present? &&
      new_guidance.guidance != existing_guidance.guidance
  end

  def using_fallback?
    new_guidance.guidance == ChiefCdsGuidance.load_fallback.guidance
  end
end
