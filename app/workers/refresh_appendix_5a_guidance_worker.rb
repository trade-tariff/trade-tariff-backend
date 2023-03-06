class RefreshAppendix5aGuidanceWorker
  include Sidekiq::Worker

  sidekiq_options retry: false

  def perform
    if Rails.application.config.chief_cds_guidance_bucket.present?
      Appendix5aPopulatorService.new.call
    end
  end
end
