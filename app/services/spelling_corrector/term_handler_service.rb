module SpellingCorrector
  class TermHandlerService
    def initialize(term)
      @term = term
    end

    def call
      term = @term.downcase

      has_digits = term.match(/\d/)
      too_small = term.length < 3

      return nil if has_digits || too_small

      term
    end
  end
end
