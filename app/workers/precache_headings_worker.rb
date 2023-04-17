class PrecacheHeadingsWorker
  include Sidekiq::Worker

  def perform(date = nil)
    date = date ? Time.zone.parse(date).to_date : Time.zone.today

    HeadingService::PrecacheService.new(date).call
  end
end
