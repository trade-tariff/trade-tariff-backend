class TreeIntegrityCheckWorker
  include Sidekiq::Worker

  sidekiq_options queue: :sync

  def perform
    check(7)
    check(14)
    check(21)
    check(28)
  end

  private

  def check(days_from_now = 0)
    date = (Time.zone.today + days_from_now.days).to_date

    TimeMachine.at(date) do
      service = TreeIntegrityCheckingService.new

      unless service.check!
        NewRelic::Agent.notice_error <<~EOMSG
          Tree integrity check failed for #{date.to_formatted_s(:db)}

          GN SIDs: #{service.failures.inspect}
        EOMSG
      end
    end
  end
end
