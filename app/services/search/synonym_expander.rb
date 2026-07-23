module Search
  class SynonymExpander
    InvalidRule = Class.new(StandardError)
    Rule = Data.define(:term, :alternatives)
    DEFAULT_RULES_PATH = Rails.root.join('config/search_synonyms.txt').freeze

    class << self
      def call(query, rules_path: DEFAULT_RULES_PATH)
        new(rules: rules_for(rules_path)).call(query)
      end

    private

      def rules_for(path)
        @rules_by_path ||= {}
        @rules_by_path[path.to_s] ||= parse(path)
      end

      def parse(path)
        path.each_line.with_index(1).flat_map do |line, line_number|
          parse_line(line, line_number)
        end
      end

      def parse_line(line, line_number)
        line = line.strip
        return [] if line.blank? || line.start_with?('#')

        return parse_directional_rule(line, line_number) if line.include?('=>')

        parse_equivalent_rule(line, line_number)
      end

      def parse_directional_rule(line, line_number)
        sides = line.split('=>', -1)
        invalid_rule!(line_number) unless sides.size == 2

        left = terms(sides.first)
        right = terms(sides.last)
        invalid_rule!(line_number) if left.empty? || right.empty?

        left.map { |term| Rule.new(term:, alternatives: right) }
      end

      def parse_equivalent_rule(line, line_number)
        equivalents = terms(line)
        invalid_rule!(line_number) if equivalents.size < 2

        equivalents.map do |term|
          Rule.new(term:, alternatives: equivalents.reject { |candidate| same_term?(candidate, term) })
        end
      end

      def terms(value)
        value.split(',').map(&:strip).compact_blank
      end

      def same_term?(left, right)
        left.casecmp?(right)
      end

      def invalid_rule!(line_number)
        raise InvalidRule, "Invalid synonym rule on line #{line_number}"
      end
    end

    def initialize(rules:)
      @rules = rules
    end

    def call(query)
      query = query.to_s.squish
      return query if query.blank?

      alternatives = matching_rules(query)
        .flat_map(&:alternatives)
        .reject { |alternative| term_present?(query, alternative) }
        .uniq(&:downcase)

      [query, *alternatives].join(' ')
    end

  private

    attr_reader :rules

    def matching_rules(query)
      rules.select { |rule| term_present?(query, rule.term) }
    end

    def term_present?(query, term)
      flexible_term = Regexp.escape(term).gsub('\\ ', '\\s+')
      query.match?(/(?<![[:alnum:]])#{flexible_term}(?![[:alnum:]])/i)
    end
  end
end
