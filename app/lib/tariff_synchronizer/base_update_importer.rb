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
      keep_record_of_presence_errors
      keep_record_of_cds_errors

      # IMPORTANT: running large update files may cause out of memory exception.
      # Run `import!` outside of this class to prevent that.
      Sequel::Model.db.transaction(reraise: true) do
        # If a error is raised during import, mark the update as failed
        Sequel::Model.db.after_rollback { @base_update.mark_as_failed }
        @base_update.import!
      end
    rescue StandardError => e
      e = e.original if e.respond_to?(:original) && e.original
      persist_exception_for_review(e)
      notify_exception(e)
      raise Sequel::Rollback
    ensure
      ActiveSupport::Notifications.unsubscribe(@sql_subscriber)
      ActiveSupport::Notifications.unsubscribe(@presence_errors_subscriber)
      ActiveSupport::Notifications.unsubscribe(@cds_errors_subscriber)
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

    def keep_record_of_presence_errors
      @presence_errors_subscriber = ActiveSupport::Notifications.subscribe(/presence_error/) do |*args|
        event = ActiveSupport::Notifications::Event.new(*args)
        klass = event.payload[:klass]
        details = event.payload[:details]
        TariffSynchronizer::TariffUpdatePresenceError.create(
          base_update: @base_update,
          model_name: klass,
          details: details.to_json,
        )
      end
    end

    def keep_record_of_cds_errors
      @cds_errors_subscriber = ActiveSupport::Notifications.subscribe(/cds_error/) do |*args|
        event = ActiveSupport::Notifications::Event.new(*args)
        record = event.payload[:record]
        xml_key = event.payload[:xml_key]
        xml_node = event.payload[:xml_node]
        exception = event.payload[:exception]
        TariffSynchronizer::TariffUpdateCdsError.create(
          base_update: @base_update,
          model_name: record.class,
          details: {
            errors: record.errors,
            xml_key:,
            xml_node:,
            exception: "#{exception.class}: #{exception.message}",
          }.to_json,
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
