module TariffKnowledge
  class RuleExtractor
    HEADING_LINK_PATTERN = %r{\[(\d{4})\]\(/headings/\1\)}
    HEADING_TEXT_PATTERN = /\bheadings?\s+(\d{4})(?:\s*(?:to|-|–)\s*(\d{4}))?/i
    DOTTED_HEADING_TEXT_PATTERN = /\b(\d{2})\.(\d{2})(?:\s*(?:to|-|–)\s*(\d{2})\.(\d{2}))?/i
    SUBHEADING_TEXT_PATTERN = /\bsubheadings?\s+(\d{4,10})(?:\s*(?:to|-|–)\s*(\d{4,10}))?/i
    CHAPTER_TEXT_PATTERN = /\bchapters?\s+(\d{2})(?:\s*(?:to|-|–)\s*(\d{2}))?/i
    SECTION_TEXT_PATTERN = /\bsections?\s+([IVX]+)(?:\s*(?:to|-|–)\s*([IVX]+))?/i
    TERM_PATTERN = /["“]([^"”]+)["”]\s+means/i

    def self.call(source:)
      new(source).call
    end

    def initialize(source)
      @source = source
    end

    def call
      split_rules.map do |rule_label, content|
        Rule.new(
          source: source,
          rule_label: rule_label,
          rule_type: rule_type_for(content),
          title: "#{source.title} #{rule_label}",
          content: content,
          references: references_for(content),
          metadata: metadata_for(content),
        )
      end
    end

  private

    attr_reader :source

    def split_rules
      normalised = source.content.to_s.gsub(/\r\n?/, "\n").strip
      normalised = remove_customs_tariff_boilerplate(normalised)
      return [] if normalised.blank?

      matches = normalised.to_enum(:scan, /(?:\A|\n)\s*(\d+[A-Z]?)\.\s*/).map do
        Regexp.last_match
      end

      return [['1', normalised]] if matches.empty?

      matches.each_with_index.map do |match, index|
        label = match[1]
        content_start = match.end(0)
        content_end = matches[index + 1]&.begin(0) || normalised.length
        [label, normalised[content_start...content_end].strip]
      end
    end

    def remove_customs_tariff_boilerplate(content)
      content.sub(/\AThere are important (?:(?:chapter|section)\s+)?note[sd]? for this part of the tariff:\s*/i, '')
    end

    def rule_type_for(content)
      downcased = content.downcase

      case downcased
      when /\bdoes not cover\b|\bexcept\b|\bexcluding\b|\bexclude[sd]?\b/
        'excludes'
      when TERM_PATTERN
        'defines_term'
      when /\bin no other heading\b|\bin no other chapter\b|\bnot elsewhere specified\b/
        'classifies_only_as'
      when /\bclassified in\b|\bclassified under\b|\bare to be classified\b|\bis to be classified\b/
        'classifies_as'
      when /\bsubject to\b/
        'subject_to'
      else
        'constrains'
      end
    end

    def references_for(content)
      references = []
      references.concat(linked_headings(content))
      references.concat(dotted_headings(content))
      references.concat(textual_subheadings(content))
      references.concat(textual_headings(content))
      references.concat(textual_chapters(content))
      references.concat(textual_sections(content))
      references.uniq
    end

    def linked_headings(content)
      content.scan(HEADING_LINK_PATTERN).map do |(heading)|
        { type: 'heading', id: heading, expression: heading }
      end
    end

    def textual_headings(content)
      content.scan(HEADING_TEXT_PATTERN).flat_map do |from, to|
        if to
          [{ type: 'heading_range', from: from, to: to, expression: "#{from} to #{to}" }]
        else
          [{ type: 'heading', id: from, expression: from }]
        end
      end
    end

    def dotted_headings(content)
      content.scan(DOTTED_HEADING_TEXT_PATTERN).flat_map do |from_chapter, from_heading, to_chapter, to_heading|
        from = "#{from_chapter}#{from_heading}"

        if to_chapter && to_heading
          to = "#{to_chapter}#{to_heading}"
          [{ type: 'heading_range', from:, to:, expression: "#{from_chapter}.#{from_heading} to #{to_chapter}.#{to_heading}" }]
        else
          [{ type: 'heading', id: from, expression: "#{from_chapter}.#{from_heading}" }]
        end
      end
    end

    def textual_subheadings(content)
      content.scan(SUBHEADING_TEXT_PATTERN).flat_map do |from, to|
        if to
          [{ type: 'goods_nomenclature_code_range', from:, to:, expression: "#{from} to #{to}" }]
        else
          [{ type: 'goods_nomenclature_code', id: from, expression: from }]
        end
      end
    end

    def textual_chapters(content)
      content.scan(CHAPTER_TEXT_PATTERN).flat_map do |from, to|
        if to
          [{ type: 'chapter_range', from: from, to: to, expression: "#{from} to #{to}" }]
        else
          [{ type: 'chapter', id: from, expression: from }]
        end
      end
    end

    def textual_sections(content)
      content.scan(SECTION_TEXT_PATTERN).flat_map do |from, to|
        if to
          [{ type: 'section_range', from: roman_to_decimal(from), to: roman_to_decimal(to), expression: "#{from} to #{to}" }]
        else
          [{ type: 'section', id: roman_to_decimal(from), expression: from }]
        end
      end
    end

    def metadata_for(content)
      term = content.match(TERM_PATTERN)&.[](1)
      metadata = {
        'source_type' => source.source_type,
        'source_id' => source.source_id,
        'source_version' => source.source_version,
      }
      metadata['defined_term'] = term if term
      metadata
    end

    def roman_to_decimal(roman)
      RomanNumerals::Converter.to_decimal(roman.upcase)
    end
  end
end
