require 'logger'

module ChangesTablePopulator
  class MyottLogger < ActiveSupport::LogSubscriber
    def populate(event)
      info "Populating the myott_changes table for day #{event.payload[:day]}:\n" \
           "Started: #{event.time}\n" \
           "Finished: #{event.end}\n" \
           "Duration (ms): #{event.duration}\n"
    end

    def populate_backlog(event)
      info "Populating the myott_changes table for period from #{event.payload[:from]} to #{event.payload[:to]}:\n" \
           "Started: #{event.time}\n" \
           "Finished: #{event.end}\n" \
           "Duration (ms): #{event.duration}\n"
    end

    def populate_failed(event)
      info "Failed populating changes:\n" \
           "Exception #{event.payload[:exception].message}\n"
    end

    def cleanup_outdated(event)
      info "Cleaning up outdated myott changes older than #{event.payload[:older_than]}:\n" \
           "Started: #{event.time}\n" \
           "Finished: #{event.end}\n" \
           "Duration (ms): #{event.duration}\n"
    end
  end
end

ChangesTablePopulator::MyottLogger.attach_to :changes_table_populator
