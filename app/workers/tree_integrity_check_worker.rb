class TreeIntegrityCheckWorker
  include Sidekiq::Worker

  def perform(days_from_now = 0)
    date = (Time.zone.today + days_from_now.days).to_date

    TimeMachine.at(date) do
      service = TreeIntegrityCheckingService.new

      unless service.check!
        Sentry.capture_message <<~EOMSG
          Tree integrity check failed for #{date.to_formatted_s(:db)}

          GN SIDs: #{service.failures.inspect}
        EOMSG
      end
    end
  end
end
