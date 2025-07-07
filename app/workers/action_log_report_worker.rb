require 'csv'

class ActionLogReportWorker
  include Sidekiq::Worker

  START_DATE = Date.new(2025, 6, 19).freeze

  def perform
    return unless TradeTariffBackend.uk?

    yesterday = Time.zone.yesterday
    start_date = START_DATE.beginning_of_day
    end_date = yesterday.end_of_day

    action_logs = PublicUsers::ActionLog
                    .where(Sequel.lit('created_at >= ? AND created_at <= ?', start_date, end_date))
                    .all

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
