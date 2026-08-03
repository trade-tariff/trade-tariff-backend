# frozen_string_literal: true

module TariffSynchronizer
  module Import
    class Error < StandardError
      attr_reader :original, :source, :context

      # Follows a chain of wrapped exceptions (however many layers deep) down to the
      # innermost one, so callers never surface a generic wrapper's message by mistake.
      def self.unwrap(exception)
        exception = exception.original while exception.respond_to?(:original) && exception.original

        exception
      end

      def initialize(message:, source:, original: nil, context: {})
        super(message)
        @source = source
        @original = original
        @context = context
        log!
      end

    private

      def log!
        Rails.logger.error(log_message)
      end

      def log_message
        lines = ["#{source.to_s.capitalize} import failed: #{original || message}"]
        context.each { |key, value| lines << "#{key.to_s.tr('_', ' ').capitalize}: #{value}" }

        backtrace = (original || self).backtrace
        lines << "Backtrace:\n#{backtrace.join("\n")}" if backtrace

        lines.join("\n")
      end
    end
  end
end
