class SpellingFileUploaderWorker
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: false

  def perform
    SpellingCorrector::FileUpdaterService.new.call
  end
end
