require 'logger'

module ChangesTablePopulator
  class Logger < ActiveSupport::LogSubscriber
    def populate(event)
      info "Populating the changes table for day #{event.payload[:day]}:\n" \
           "Started: #{event.time}\n" \
           "Finished: #{event.end}\n" \
           "Duration (ms): #{event.duration}\n"
    end

    def populate_backlog(event)
      info "Populating the changes table for period from #{event.payload[:from]} to #{event.payload[:to]}:\n" \
           "Started: #{event.time}\n" \
           "Finished: #{event.end}\n" \
           "Duration (ms): #{event.duration}\n"
    end

    def populate_failed(event)
      info "Failed populating changes:\n" \
           "Exception #{event.payload[:exception].message}\n"
    end

    def cleanup_outdated(event)
      info "Cleaning up outdated changes older than #{event.payload[:older_than]}:\n" \
           "Started: #{event.time}\n" \
           "Finished: #{event.end}\n" \
           "Duration (ms): #{event.duration}\n"
    end
  end
end

ChangesTablePopulator::Logger.attach_to :changes_table_populator unless Rails.env.test?
