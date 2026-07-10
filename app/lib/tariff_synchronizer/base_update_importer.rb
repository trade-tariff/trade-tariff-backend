module TariffSynchronizer
  class BaseUpdateImporter
    def self.perform(base_update)
      new(base_update).apply
    end

    def initialize(base_update)
      @base_update = base_update
      @database_queries = RingBuffer.new(10)
    end

    def apply
      return unless @base_update.pending?

      track_latest_sql_queries

      @base_update.import!
    rescue StandardError => e
      @base_update.mark_as_failed
      e = e.original if e.respond_to?(:original) && e.original
      persist_exception_for_review(e)
      notify_exception(e)
    ensure
      ActiveSupport::Notifications.unsubscribe(@sql_subscriber)
    end

  private

    # Tracks the last 10 SQL queries executed during the import.
    # These are logged if there is an exception.
    def track_latest_sql_queries
      @sql_subscriber = ActiveSupport::Notifications.subscribe(/sql\.sequel/) do |*args|
        event = ActiveSupport::Notifications::Event.new(*args)

        binds = if event.payload.fetch(:binds, []).present?
                  event.payload[:binds].map { |column, value|
                    [column.name, value]
                  }.inspect
                end

        @database_queries.push(
          sprintf('(%{class_name}) %{sql} %{binds}',
                  class_name: event.payload[:name],
                  sql: event.payload[:sql].squeeze(' '),
                  binds:),
        )
      end
    end

    def persist_exception_for_review(exception)
      @base_update.update(exception_class: "#{exception.class}: #{exception.message}",
                          exception_backtrace: exception.backtrace.join("\n"),
                          exception_queries: @database_queries.join("\n"))
    end

    def notify_exception(exception)
      TariffLogger.failed_update(
        exception:,
        update: @base_update,
        database_queries: @database_queries,
      )
    end
  end
end
