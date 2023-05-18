class ReportWorker
  include Sidekiq::Worker

  sidekiq_options retry: false

  def perform
    Reporting::Basic.generate
    Reporting::DeclarableDuties.generate
  end
end
