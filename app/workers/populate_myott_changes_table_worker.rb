class MyottPopulateChangesTableWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform
    MyottChangesTablePopulator.populate
    MyottChangesTablePopulator.cleanup_outdated
  end
end
