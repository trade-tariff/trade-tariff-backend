module TariffKnowledge
  class NoteMarkerTrie
    Match = Data.define(:kind, :marker, :depth, :token, :length)

    ROMAN_MARKERS = %w[i ii iii iv v vi vii viii ix x xi xii].freeze
    DOTTED_ALPHA_MARKERS = ('a'..'z').map { |letter| "#{letter}." }.freeze
    ALPHA_MARKERS = (
      DOTTED_ALPHA_MARKERS +
      ((('a'..'z').to_a - %w[i v x]) + %w[ij]).flat_map { |letter| ["(#{letter})", "#{letter})"] } +
      %w[ij.]
    ).freeze
    ROMAN_MARKER_TOKENS = (
      (ROMAN_MARKERS - %w[i v x]).flat_map { |roman| ["#{roman}.", "(#{roman})", "#{roman})"] } +
      %w[i v x].flat_map { |roman| ["(#{roman})", "#{roman})"] }
    ).freeze

    DEFAULT_MARKERS = {
      numeric: { depth: 1, tokens: (1..99).map { |number| "#{number}." } },
      roman: { depth: 3, tokens: ROMAN_MARKER_TOKENS },
      alpha: { depth: 2, tokens: ALPHA_MARKERS },
      bullet: { depth: 4, tokens: ['-', '–', '—'] },
    }.freeze

    def self.default = @default ||= new(DEFAULT_MARKERS)

    def initialize(marker_families)
      @root = {}

      marker_families.each do |kind, definition|
        definition.fetch(:tokens).each do |token|
          register(token, kind, definition.fetch(:depth))
        end
      end
    end

    def match(token)
      node = root
      best_match = nil
      normalized_token = token.to_s.strip.downcase

      normalized_token.each_char do |character|
        node = node[character]
        break unless node

        best_match = node[:match] if node[:match]
      end

      best_match
    end

  private

    attr_reader :root

    def register(token, kind, depth)
      node = root
      normalized_token = token.downcase

      normalized_token.each_char do |character|
        node[character] ||= {}
        node = node[character]
      end

      node[:match] = Match.new(
        kind:,
        marker: normalize_marker(token),
        depth:,
        token:,
        length: token.length,
      )
    end

    def normalize_marker(token)
      marker = token.downcase

      return marker if DEFAULT_MARKERS.fetch(:bullet).fetch(:tokens).include?(marker)

      marker.delete_prefix('(').delete_suffix('.').delete_suffix(')').delete_suffix(')')
    end
  end
end
