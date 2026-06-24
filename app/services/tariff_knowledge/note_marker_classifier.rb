module TariffKnowledge
  class NoteMarkerClassifier
    Event = Data.define(:fragment, :kind, :marker, :depth, :path_segment, :title, :body, :raw_text)

    HEADING_MARKER = /\A#+\s+(?<title>.+)\z/

    def self.call(...) = new(...).call

    def initialize(fragment, trie: NoteMarkerTrie.default)
      @fragment = fragment
      @trie = trie
    end

    def call
      text = fragment.content.to_s.squish
      heading_match = text.match(HEADING_MARKER)

      return heading_event(heading_match[:title].squish, text) if heading_match

      token, body = text.split(/\s+/, 2)
      marker_match = trie.match(token)

      return continuation_event(text) unless marker_match
      return continuation_event(text) unless valid_marker_boundary?(token, marker_match)

      marker_event(marker_match, marker_body(token, marker_match, body), text)
    end

  private

    attr_reader :fragment, :trie

    def heading_event(title, raw_text)
      path_segment = title.parameterize(separator: '_')

      Event.new(
        fragment:,
        kind: :heading,
        marker: path_segment,
        depth: 0,
        path_segment:,
        title:,
        body: '',
        raw_text:,
      )
    end

    def marker_event(marker_match, body, raw_text)
      title, event_body = title_and_body(marker_match, body)

      Event.new(
        fragment:,
        kind: marker_match.kind,
        marker: marker_match.marker,
        depth: marker_match.depth,
        path_segment: marker_match.marker,
        title:,
        body: event_body,
        raw_text:,
      )
    end

    def continuation_event(raw_text)
      Event.new(
        fragment:,
        kind: :continuation,
        marker: nil,
        depth: nil,
        path_segment: nil,
        title: nil,
        body: raw_text,
        raw_text:,
      )
    end

    def title_and_body(marker_match, body)
      case marker_match.kind
      when :numeric
        [marker_match.marker, body]
      when :alpha
        [body.presence, '']
      else
        [nil, body]
      end
    end

    def marker_body(token, marker_match, body)
      suffix = token[marker_match.length..]

      [suffix, body].compact_blank.join(' ').squish
    end

    def valid_marker_boundary?(token, marker_match)
      suffix = token[marker_match.length..].to_s

      # Exact marker tokens are always valid. Compact prefixes are deliberately
      # narrow: only numeric markers may absorb an alphabetic suffix such as
      # "1.foo"; decimals and abbreviation-like alpha/roman prefixes stay prose.
      suffix.blank? || marker_match.kind == :numeric && suffix.match?(/\A[[:alpha:]]/)
    end
  end
end
