require 'logger'

module DeltaTablesGenerator
  class Logger < ActiveSupport::LogSubscriber
    def generate(event)
      info "Generating the deltas for day #{event.payload[:day]}:\n" \
           "Started: #{event.time}\n" \
           "Finished: #{event.end}\n" \
           "Duration (ms): #{event.duration}\n"
    end

    def generate_backlog(event)
      info "Generating the deltas for period from #{event.payload[:from]} to #{event.payload[:to]}:\n" \
           "Started: #{event.time}\n" \
           "Finished: #{event.end}\n" \
           "Duration (ms): #{event.duration}\n"
    end

    def failed_generation(event)
      info "Failed generating deltas:\n" \
           "Exception #{event.payload[:exception].message}\n"
    end

    def cleanup_outdated(event)
      info "Cleaning up outdated deltas older than #{event.payload[:cleanup_older_than]}:\n" \
           "Started: #{event.time}\n" \
           "Finished: #{event.end}\n" \
           "Duration (ms): #{event.duration}\n"
    end
  end
end

DeltaTablesGenerator::Logger.attach_to :delta_tables_generator
