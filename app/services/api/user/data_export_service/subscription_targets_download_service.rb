module Api
  module User
    module DataExportService
      class SubscriptionTargetsDownloadService
        def initialize(subscription)
          @subscription = subscription
        end

        def call
          package = TimeMachine.now do
            Api::User::ActiveCommoditiesService.new(@subscription).generate_report
          end

          filename_date = TimeMachine.now { Time.zone.today.strftime('%Y-%m-%d') }
          filename = "commodity_watch_list-your_codes_#{filename_date}.xlsx"

          {
            file_name: filename,
            content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            body: package.to_stream.read,
          }
        end
      end
    end
  end
end
