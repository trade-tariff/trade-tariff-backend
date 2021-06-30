require 'logger'

module DeltaTablesGenerator
  class Logger < ActiveSupport::LogSubscriber
    def generate(event)
      day_message('', event)
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

    def perform_import_commodity_code_started(event)
      day_message('commodity code started, ', event)
    end

    def day_message(label, event)
      info "Generating the deltas for #{label}day #{event.payload[:day]}:\n" \
           "Started: #{event.time}\n" \
           "Finished: #{event.end}\n" \
           "Duration (ms): #{event.duration}\n"
    end
  end
end

DeltaTablesGenerator::Logger.attach_to :delta_tables_generator
