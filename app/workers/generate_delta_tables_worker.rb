class GenerateDeltaTablesWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync, retry: false

  def perform
    logger.info 'Running GenerateDeltaTablesWorker'
    logger.info 'Generating...'
    DeltaTablesGenerator.generate
    DeltaTablesGenerator.cleanup_outdated
  end
end
