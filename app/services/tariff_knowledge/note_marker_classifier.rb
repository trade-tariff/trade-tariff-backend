module TariffKnowledge
  class NoteMarkerClassifier
    Event = Data.define(:fragment, :kind, :marker, :depth, :path_segment, :title, :body, :raw_text)

    HEADING_MARKER = /\A#+\s+(?<title>.+)\z/
    BULLET_ALPHA_SECTION = /\A\((?<marker>[A-Z])\)\.?\s+(?<body>.+)\z/
    ALPHA_SECTION_MARKER = /\A\((?<marker>[A-Z])\)\.\z/

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
      alpha_section_match = token.to_s.match(ALPHA_SECTION_MARKER)

      return alpha_section_event(alpha_section_match[:marker], body.to_s.squish, text) if alpha_section_match

      marker_match = trie.match(token)

      return continuation_event(text) unless marker_match
      return continuation_event(text) unless valid_marker_boundary?(token, marker_match)

      marker_body = marker_body(token, marker_match, body)
      embedded_section = embedded_bullet_alpha_section(marker_match, marker_body)

      return alpha_section_event(embedded_section[:marker], embedded_section[:body], text) if embedded_section

      marker_event(marker_match, marker_body, text)
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
      kind = marker_kind(marker_match)
      marker = marker(marker_match)
      title, event_body = title_and_body(kind, marker_match, body)

      Event.new(
        fragment:,
        kind:,
        marker:,
        depth: marker_match.depth,
        path_segment: marker,
        title:,
        body: event_body,
        raw_text:,
      )
    end

    def alpha_section_event(marker, body, raw_text)
      Event.new(
        fragment:,
        kind: :alpha_section,
        marker:,
        depth: 2,
        path_segment: marker,
        title: body.presence,
        body: '',
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

    def title_and_body(kind, marker_match, body)
      case kind
      when :numeric
        [marker_match.marker, body]
      when :alpha, :alpha_section
        [body.presence, '']
      else
        [nil, body]
      end
    end

    def marker_body(token, marker_match, body)
      suffix = token[marker_match.length..]

      [suffix, body].compact_blank.join(' ').squish
    end

    def marker_kind(marker_match)
      return :alpha_section if uppercase_alpha_marker?(marker_match)

      marker_match.kind
    end

    def marker(marker_match)
      return marker_match.marker.upcase if uppercase_alpha_marker?(marker_match)

      marker_match.marker
    end

    def uppercase_alpha_marker?(marker_match)
      marker_match.kind == :alpha && marker_text(marker_match).match?(/[A-Z]/)
    end

    def marker_text(marker_match)
      fragment.content.to_s.squish.first(marker_match.length)
    end

    def embedded_bullet_alpha_section(marker_match, body)
      return unless marker_match.kind == :bullet

      body.match(BULLET_ALPHA_SECTION)
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
