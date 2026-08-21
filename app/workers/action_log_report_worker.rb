require 'csv'

class ActionLogReportWorker
  include Sidekiq::Worker

  # Report jobs: one delayed retry, avoid Sidekiq default (25).
  sidekiq_options retry: 1, retry_in: 1.hour

  def perform
    return unless TradeTariffBackend.uk?

    yesterday = Time.zone.yesterday
    start_date = 1.month.ago.beginning_of_day
    end_date = yesterday.end_of_day

    # Stream the dataset (no .all) so large months do not load entirely into memory.
    action_logs = PublicUsers::ActionLog
                    .where(created_at: start_date..end_date)
                    .order(:id)

    return if action_logs.empty?

    csv_data = generate_csv(action_logs)
    ActionLogMailer.daily_report(csv_data, yesterday.strftime('%Y-%m-%d')).deliver_now
  end

private

  def generate_csv(action_logs)
    CSV.generate do |csv|
      csv << ['ID', 'User ID', 'Action', 'Created At']
      action_logs.each do |log|
        csv << [
          log.id,
          log.user_id,
          log.action,
          log.created_at,
        ]
      end
    end
  end
end
