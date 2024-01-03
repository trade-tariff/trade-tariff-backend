class RefreshAppendix5aGuidanceWorker
  include Sidekiq::Worker

  sidekiq_options retry: false

  def perform
    if Rails.application.config.persistence_bucket.present?
      Appendix5aPopulatorService.new.call
    end
  end
end
