module SpellingCorrector
  module Loaders
    class Intercepts
      def load
        each_term do |term|
          terms[term] += 1
        end

        terms
      end

      def terms
        @terms ||= Hash.new(0)
      end

      private

      def each_term(&block)
        Beta::Search::InterceptMessage.intercept_messages.keys.join(' ').split(' ').each(&block)
      end
    end
  end
end
