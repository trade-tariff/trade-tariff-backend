class PrecacheHeadingsWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync

  def perform(date = nil)
    date = date ? Time.zone.parse(date).to_date : Time.zone.tomorrow

    HeadingService::PrecacheService.new(date).call
  end
end
