module SemanticLogger
  module Appender
    class DataDog < SemanticLogger::Appender::Http
      attr_accessor :source_type, :index
      
      def initialize(token: nil,
                     source_type: nil,
                     index: nil,
                     compress: true,
                     **args,
                     &block)

        @source_type = source_type
        @index       = index

        super(compress: compress, **args, &block)

        @header["DD-API-KEY"] = "#{ENV['DD_API_KEY']}"
      end

      def call(log, logger)
        h                     = SemanticLogger::Formatters::Raw.new(time_format: :seconds).call(log, logger)
        h.delete(:host)
        message               = {
          source: logger.application,
          host:   logger.host + "Octavian Machine",
          time:   h.delete(:time),
          event:  h
        }
        message[:sourcetype]  = source_type if source_type
        message[:index]       = index if index
        message.to_json
      end
    end
  end
end