require 'cgi'
require 'uri'

module Api
  module Internal
    module ProductDescription
      class UrlContentExtractor
        TOKEN_SEPARATORS = /[^a-z0-9]+/
        IGNORED_HOST_TOKENS = %w[www co com org net uk].freeze
        IGNORED_PATH_TOKENS = %w[p product products shop groceries dp gp en gb uk html htm pd clp].freeze
        UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/
        LONG_HEX_PATTERN = /\A[0-9a-f]{16,}\z/
        TOKEN_LIKE_PATTERN = /\A(?=.*[a-z])(?=.*\d)[a-z0-9_-]{20,}\z/

        def self.call(url)
          new(url).call
        end

        def initialize(url)
          @url = url.to_s
        end

        def call
          product_words = path_words
          words = product_words.present? ? (host_words + product_words).uniq.join(' ') : nil

          ExtractedContent.new(
            title: words.presence,
            meta_description: nil,
            open_graph_title: nil,
            open_graph_description: nil,
            h1: nil,
            product_data: words.present? ? { 'source' => 'url' } : {},
            body_text: words.present? ? "URL path suggests: #{words}" : nil,
          )
        end

        private

        def uri
          @uri ||= URI.parse(@url)
        rescue URI::InvalidURIError
          nil
        end

        def host_words
          tokenize(uri&.host).reject { |word| IGNORED_HOST_TOKENS.include?(word) }
        end

        def path_words
          path_segments = uri&.path.to_s.split('/')

          words = path_segments.flat_map do |segment|
            next [] if risky_segment?(segment)

            tokenize(CGI.unescape(segment))
          end

          words.reject { |word| ignored_path_word?(word) || risky_word?(word) }
        end

        def tokenize(value)
          value.to_s
            .downcase
            .split(TOKEN_SEPARATORS)
            .filter_map { |word| normalize_word(word) }
        end

        def normalize_word(word)
          word = word.to_s.strip
          return if word.length < 2 && word != 't'
          return if risky_word?(word)

          word
        end

        def ignored_path_word?(word)
          IGNORED_PATH_TOKENS.include?(word) || word.match?(/\A\d+\z/) || word.match?(/\Aclp\d+\z/)
        end

        def risky_segment?(segment)
          decoded_segment = CGI.unescape(segment.to_s)

          decoded_segment.include?('@') ||
            decoded_segment.include?('=') ||
            decoded_segment.match?(UUID_PATTERN)
        end

        def risky_word?(word)
          word.match?(UUID_PATTERN) ||
            word.match?(LONG_HEX_PATTERN) ||
            word.match?(TOKEN_LIKE_PATTERN)
        end
      end
    end
  end
end
