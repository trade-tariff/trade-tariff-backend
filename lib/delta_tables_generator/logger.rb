module DeltaTablesGenerator
  class Logger < ActiveSupport::LogSubscriber
    def generate(event)
      message = "Generating the deltas for day #{event.payload[:day]}:\n" \
                "Started: #{event.time}\n" \
                "Finished: #{event.end}\n" \
                "Duration (ms): #{event.duration}\n"
      info message
      puts message
    end

    def generate_backlog(event)
      message = "Generating the deltas for period from #{event.payload[:from]} to #{event.payload[:to]}:\n" \
                "Started: #{event.time}\n" \
                "Finished: #{event.end}\n" \
                "Duration (ms): #{event.duration}\n"
      info message
      puts message
    end

    def failed_generation(event)
      message = "Failed generating deltas:\n" \
                "Exception #{event.payload[:exception].backlog}\n"
      info message
      puts message
    end
  end
end

DeltaTablesGenerator::Logger.attach_to :delta_tables_generator

ActiveSupport::Notifications.subscribe('generate.delta_tables_generator')
ActiveSupport::Notifications.subscribe('generate_backlog.delta_tables_generator')
ActiveSupport::Notifications.subscribe('failed_generation.delta_tables_generator')
