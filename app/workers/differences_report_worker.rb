class DifferencesReportWorker
  include Sidekiq::Worker

  sidekiq_options retry: 1, retry_in: 1.hour

  def perform(deliver_email = true)
    differences = generate_differences

    if deliver_email
      send_differences_email(differences)
    end
  end

  private

  def generate_differences
    Reporting::Differences.generate
  end

  def send_differences_email(differences)
    ReportsMailer.differences(differences).deliver_now
  end
end
