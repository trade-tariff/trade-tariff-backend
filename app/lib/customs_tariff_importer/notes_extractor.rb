require 'zip'

module CustomsTariffImporter
  class NotesExtractor
    WORD_NS = { 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main' }.freeze

    SECTION_PATTERN          = /\ASECTION\s+([IVX]+)\z/i
    CHAPTER_PATTERN          = /\ACHAPTER\s+(\d+)\z/
    CHAPTER_NOTES_PATTERN    = /\AChapter\s+[Nn]otes?\z/i
    ADDITIONAL_NOTES_PATTERN = /\AAdditional\s+[Cc]hapter\s+[Nn]otes?\z/i
    SUBHEADING_NOTES_PATTERN = /\ASubheading\s+[Nn]otes?\z/i
    SECTION_NOTES_PATTERN    = /\ASection\s+[Nn]otes?\z/i
    GENERAL_RULES_PATTERN    = /\AGeneral\s+Interpretive\s+Rules?\z/i
    RULE_PATTERN             = /\ARule\s+(\d+)\z/i
    COMMODITY_CODE_PATTERN   = /\A\d{10}\z/
    PART_BOUNDARY_PATTERN    = /\APART\s+\w+/i
    NUMBERED_NOTE_PATTERN    = /\A1\.\s*[A-Za-z(]/
    SINGLETON_EXPRESSION_WRAPPER_CHAPTERS = %w[74 78 80].freeze

    Result = Data.define(:chapters, :sections, :general_rules)

    def initialize(version, docx_content)
      @version = version
      @docx_content = docx_content
      @formatter = Formatter.new
    end

    def call
      Instrumentation.parse_started(version: @version)

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      xml = read_document_xml
      paragraphs = extract_paragraphs(xml)
      result = parse_notes(paragraphs)
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)

      Instrumentation.document_parsed(
        version: @version,
        chapters: result.chapters.size,
        sections: result.sections.size,
        rules: result.general_rules.size,
        duration_ms:,
      )

      result
    rescue StandardError => e
      Instrumentation.parse_failed(version: @version, error_class: e.class.name, error_message: e.message)
      raise
    end

    private

    def read_document_xml
      xml_content = nil

      Tempfile.create(['tariff_document', '.docx']) do |tmpfile|
        tmpfile.binmode
        tmpfile.write(@docx_content)
        tmpfile.flush

        Zip::File.open(tmpfile.path) do |zip|
          entry = zip.find_entry('word/document.xml')
          raise 'word/document.xml not found in .docx archive' unless entry

          xml_content = entry.get_input_stream.read
        end
      end

      xml_content
    end

    def extract_paragraphs(xml)
      @formatter.extract_paragraphs(xml)
    end

    def parse_notes(paragraphs)
      @state           = :scanning
      @current_section = nil
      @current_chapter = nil
      @current_rule    = nil
      @note_lines      = []
      @chapters        = {}
      @sections        = {}
      @general_rules   = {}
      @current_paragraph = nil
      @formatter.reset_note_formatting_context

      paragraphs.each do |para|
        @current_paragraph = para
        send(:"handle_#{@state}", para[:text])
      end

      finalize_chapter_note
      finalize_section_note
      finalize_rule

      Result.new(chapters: @chapters, sections: @sections, general_rules: @general_rules)
    end

    def handle_scanning(text)
      if text.match?(GENERAL_RULES_PATTERN)
        @state = :in_gri
      elsif (m = text.match(SECTION_PATTERN))
        @current_section = m[1].upcase
        @note_lines = []
        @state = :in_section
      elsif (m = text.match(CHAPTER_PATTERN))
        @current_chapter = sprintf('%02d', m[1].to_i)
        @note_lines = []
        @state = :in_chapter
      end
    end

    def handle_in_gri(text)
      if (m = text.match(RULE_PATTERN))
        finalize_rule
        @current_rule = m[1]
        @note_lines = []
        @state = :collecting_rule
      elsif text.match?(PART_BOUNDARY_PATTERN) || text.match?(SECTION_PATTERN)
        @state = :scanning
      end
    end

    def handle_collecting_rule(text)
      if text.match?(PART_BOUNDARY_PATTERN)
        finalize_rule
        @state = :scanning
      elsif (m = text.match(RULE_PATTERN))
        finalize_rule
        @current_rule = m[1]
        @note_lines = []
      elsif text.match?(SECTION_PATTERN)
        finalize_rule
        @current_section = text.match(SECTION_PATTERN)[1].upcase
        @note_lines = []
        @state = :in_section
      elsif text.present? || (@note_lines.any? && @note_lines.last.present?)
        append_note_line(text)
      end
    end

    def handle_in_section(text)
      if text.match?(SECTION_NOTES_PATTERN)
        @note_lines = []
        @state = :collecting_section
      elsif (m = text.match(SECTION_PATTERN))
        finalize_section_note
        @current_section = m[1].upcase
        @note_lines = []
      elsif (m = text.match(CHAPTER_PATTERN))
        @current_chapter = sprintf('%02d', m[1].to_i)
        @note_lines = []
        @state = :in_chapter
      end
    end

    def handle_collecting_section(text)
      if (m = text.match(SECTION_PATTERN))
        finalize_section_note
        @current_section = m[1].upcase
        @note_lines = []
        @state = :in_section
      elsif (m = text.match(CHAPTER_PATTERN))
        finalize_section_note
        @current_chapter = sprintf('%02d', m[1].to_i)
        @note_lines = []
        @state = :in_chapter
      elsif text.match?(COMMODITY_CODE_PATTERN)
        finalize_section_note
        @state = :skipping
      elsif text.present? || (@note_lines.any? && @note_lines.last.present?)
        append_note_line(text)
      end
    end

    def handle_in_chapter(text)
      if text.match?(SECTION_NOTES_PATTERN)
        @note_lines = []
        @state = :collecting_section
      elsif text.match?(CHAPTER_NOTES_PATTERN)
        @note_lines = []
        @state = :collecting_chapter
      elsif text.match?(ADDITIONAL_NOTES_PATTERN)
        @note_lines = []
        append_note_line(text)
        @state = :collecting_chapter
      elsif text.match?(SUBHEADING_NOTES_PATTERN)
        @note_lines = []
        append_note_line(text)
        @state = :collecting_chapter
      elsif text.match?(NUMBERED_NOTE_PATTERN)
        @note_lines = []
        append_note_line(text)
        @state = :collecting_chapter
      elsif (m = text.match(CHAPTER_PATTERN))
        finalize_chapter_note
        @current_chapter = sprintf('%02d', m[1].to_i)
        @note_lines = []
      elsif (m = text.match(SECTION_PATTERN))
        finalize_chapter_note
        @current_section = m[1].upcase
        @note_lines = []
        @state = :in_section
      end
    end

    def handle_collecting_chapter(text)
      if text.match?(COMMODITY_CODE_PATTERN)
        finalize_chapter_note
        @note_lines = []
        @state = :skipping
      elsif text.match?(ADDITIONAL_NOTES_PATTERN)
        append_note_line(text)
      elsif (m = text.match(CHAPTER_PATTERN))
        finalize_chapter_note
        @current_chapter = sprintf('%02d', m[1].to_i)
        @note_lines = []
        @state = :in_chapter
      elsif (m = text.match(SECTION_PATTERN))
        finalize_chapter_note
        @current_section = m[1].upcase
        @note_lines = []
        @state = :in_section
      elsif text.present? || (@note_lines.any? && @note_lines.last.present?)
        append_note_line(text)
      end
    end

    def handle_skipping(text)
      if (m = text.match(CHAPTER_PATTERN))
        @current_chapter = sprintf('%02d', m[1].to_i)
        @note_lines = []
        @state = :in_chapter
      elsif (m = text.match(SECTION_PATTERN))
        @current_section = m[1].upcase
        @note_lines = []
        @state = :in_section
      end
    end

    def finalize_chapter_note
      return if @current_chapter.nil?

      content = @formatter.normalize_note_lines(@note_lines, chapter: true, current_chapter: @current_chapter).join("\n").strip
      @chapters[@current_chapter] = content if content.present?
      @current_chapter = nil
      @note_lines = []
      @formatter.reset_note_formatting_context
    end

    def finalize_section_note
      return if @current_section.nil?

      content = @formatter.normalize_note_lines(@note_lines, section: true).join("\n").strip
      @sections[RomanNumerals::Converter.to_decimal(@current_section)] = content if content.present?
      @current_section = nil
      @note_lines = []
      @formatter.reset_note_formatting_context
    end

    def finalize_rule
      return if @current_rule.nil?

      content = @note_lines.join("\n").strip
      @general_rules[@current_rule] = content if content.present?
      @current_rule = nil
      @note_lines = []
    end

    def append_note_line(text)
      @formatter.append_note_line(@note_lines, text, paragraph: @current_paragraph)
    end
  end
end
