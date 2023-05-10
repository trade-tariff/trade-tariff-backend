class BasicReportWorker
  include Sidekiq::Worker

  sidekiq_options retry: false

  def perform
    Reporting::Basic.generate
  end
end
