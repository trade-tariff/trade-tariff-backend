class AggregatedSynonym
  SYNONYM_RANGE = '[\w, -’]'.freeze
  EXPLICIT_MAPPING_REGEX = /^(?<lhs>#{SYNONYM_RANGE}+) => ?(?<_rhs>#{SYNONYM_RANGE}+)$/

  def self.exists?(search_query)
    aggregated_synonyms.include?(search_query&.downcase)
  end

  def self.aggregated_synonyms
    @aggregated_synonyms ||= load_synonyms.each_with_object(Set.new) do |synonym_line, acc|
      explicit_match = synonym_line.match(EXPLICIT_MAPPING_REGEX)

      synonyms = if explicit_match
                   # Explicit synonyms
                   explicit_match[:lhs]
                 else
                   # Equivalent synonyms
                   synonym_line
                 end

      synonyms.split(',').map do |synonym|
        acc << synonym.strip
      end
    end
  end

  def self.load_synonyms
    File.readlines(TradeTariffBackend.aggregated_synonyms_file)
  end
end
