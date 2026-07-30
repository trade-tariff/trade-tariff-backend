module Search
  module ExpansionDeciders
    class CasingAndEvidence < Base
      NON_WORD_TOKEN_PATTERN = /\b[A-Z]{2,6}\b/

      def call
        return 'non_word_token' if query.scan(NON_WORD_TOKEN_PATTERN).any?

        super
      end
    end
  end
end
