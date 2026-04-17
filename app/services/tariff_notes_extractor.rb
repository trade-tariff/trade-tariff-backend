class TariffNotesExtractor
  WORD_NS = { 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main' }.freeze

  SECTION_PATTERN             = /\ASECTION\s+([IVX]+)/i
  CHAPTER_PATTERN             = /\ACHAPTER\s+(\d+)/i
  CHAPTER_NOTES_PATTERN       = /\AChapter\s+[Nn]otes?\z/i
  ADDITIONAL_NOTES_PATTERN    = /\AAdditional\s+[Cc]hapter\s+[Nn]otes?\z/i
  SECTION_NOTES_PATTERN       = /\ASection\s+[Nn]otes?\z/i
  GENERAL_RULES_PATTERN       = /\AGeneral\s+Interpretive\s+Rules?\z/i
  RULE_PATTERN                = /\ARule\s+(\d+)\z/i
  COMMODITY_CODE_PATTERN      = /\A\d{10}\z/
  # Any "PART X –" heading signals the end of the GRI section (e.g. "PART THREE – ANNEXES")
  PART_BOUNDARY_PATTERN       = /\APART\s+\w+/i

  Result = Data.define(:chapters, :sections, :general_rules)

  def initialize(docx_content)
    @docx_content = docx_content
  end

  def call
    xml = read_document_xml
    paragraphs = extract_paragraphs(xml)
    parse_notes(paragraphs)
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
    doc = Nokogiri::XML(xml)
    doc.xpath('//w:p', WORD_NS).map do |para|
      style = para.at_xpath('.//w:pStyle', WORD_NS)&.attr('w:val').to_s
      text = para.xpath('.//w:t', WORD_NS).map(&:text).join.strip
      { style:, text: }
    end
  end

  def parse_notes(paragraphs)
    # States:
    #   :scanning           — initial, looking for GRI or Roman SECTION headings
    #   :in_gri             — inside "General Interpretive Rules", awaiting "Rule N"
    #   :collecting_rule    — accumulating lines for a GRI rule
    #   :in_section         — seen a Roman SECTION heading, awaiting "Section Notes"
    #   :collecting_section — accumulating section note lines
    #   :in_chapter         — seen a CHAPTER heading, awaiting "Chapter Notes"
    #   :collecting_chapter — accumulating chapter note lines
    #   :skipping           — past notes, ignoring commodity table until next heading
    @state           = :scanning
    @current_section = nil
    @current_chapter = nil
    @current_rule    = nil
    @note_lines      = []
    @chapters        = {}
    @sections        = {}
    @general_rules   = {}

    paragraphs.each do |para|
      text = para[:text]
      next if text.blank?

      send(:"handle_#{@state}", text)
    end

    finalize_chapter_note
    finalize_section_note
    finalize_rule

    Rails.logger.info "TariffNotesExtractor: #{@chapters.size} chapter notes, #{@sections.size} section notes, #{@general_rules.size} general rules"

    Result.new(chapters: @chapters, sections: @sections, general_rules: @general_rules)
  end

  # ── State handlers ────────────────────────────────────────────────────────

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
      # "PART THREE – ANNEXES" or a Roman-numeral SECTION — leaving GRI area entirely
      @state = :scanning
    end
  end

  def handle_collecting_rule(text)
    if text.match?(PART_BOUNDARY_PATTERN)
      # End of GRI section (e.g. "PART THREE – ANNEXES") — finalise last rule and stop
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
    else
      @note_lines << text
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
      finalize_section_note
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
    else
      @note_lines << text
    end
  end

  def handle_in_chapter(text)
    if text.match?(CHAPTER_NOTES_PATTERN)
      @note_lines = []
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
      # Continue accumulating — additional chapter notes belong to the same chapter
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
    else
      @note_lines << text
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

  # ── Finalisers ────────────────────────────────────────────────────────────

  def finalize_chapter_note
    return if @current_chapter.nil?

    content = @note_lines.reject(&:blank?).join("\n").strip
    @chapters[@current_chapter] = content if content.present?
    @current_chapter = nil
    @note_lines = []
  end

  def finalize_section_note
    return if @current_section.nil?

    content = @note_lines.reject(&:blank?).join("\n").strip
    @sections[@current_section] = content if content.present?
    @current_section = nil
    @note_lines = []
  end

  def finalize_rule
    return if @current_rule.nil?

    content = @note_lines.reject(&:blank?).join("\n").strip
    @general_rules[@current_rule] = content if content.present?
    @current_rule = nil
    @note_lines = []
  end
end
