# Formats goods nomenclature descriptions into clean HTML with only <br>, <sup>,
# and <sub> tags. Handles both UK descriptions (mostly pre-converted HTML) and XI
# descriptions (raw TARIC markup). TARIC spec: https://silo.tips/download/taric-file-distribution
#
# Pipeline (order matters):
#   1. Decode HTML entities (&ge;, &nbsp;, &#NNN;, &#xHH;)
#   2. Strip control characters, convert TAB/LF
#   3. TARIC markup -> HTML (|| before | is critical, see phase 3)
#   4. Strip disallowed HTML tags (keep br, sup, sub)
#   5. Unicode normalisation (smart quotes -> ASCII, superscripts -> <sup>)
#   6. Fix encoding, collapse whitespace, strip
#
# NBSP (U+00A0) is preserved - it prevents line-wrap between numbers and units.
#
class DescriptionHtmlFormatter
  UNICODE_TO_ASCII = {
    "\u2018" => "'",         # left single quotation mark
    "\u2019" => "'",         # right single quotation mark
    "\u201C" => '"',         # left double quotation mark
    "\u201D" => '"',         # right double quotation mark
    "\u2013" => '-',         # en-dash
    "\u2014" => '-',         # em-dash
    "\u2011" => '-',         # non-breaking hyphen
    "\u2212" => '-',         # minus sign
    "\u200B" => '',          # zero-width space
    "\u00AD" => '',          # soft hyphen
    "\u2265" => '>=',        # greater-than or equal to
    "\u2264" => '<=',        # less-than or equal to
    "\u00D7" => 'x',         # multiplication sign
    "\u2103" => "\u00B0C",   # degree celsius -> degree sign + C
  }.freeze

  UNICODE_SUPERSCRIPTS = {
    "\u2070" => '0',
    "\u00B9" => '1',
    "\u00B2" => '2',
    "\u00B3" => '3',
    "\u2074" => '4',
    "\u2075" => '5',
    "\u2076" => '6',
    "\u2077" => '7',
    "\u2078" => '8',
    "\u2079" => '9',
  }.freeze

  UNICODE_SUBSCRIPTS = {
    "\u2080" => '0',
    "\u2081" => '1',
    "\u2082" => '2',
    "\u2083" => '3',
    "\u2084" => '4',
    "\u2085" => '5',
    "\u2086" => '6',
    "\u2087" => '7',
    "\u2088" => '8',
    "\u2089" => '9',
  }.freeze

  HTML_ENTITY_MAP = {
    '&ge;' => '>=',
    '&le;' => '<=',
    '&times;' => 'x',
    '&deg;' => "\u00B0",
    '&amp;' => '&',
    '&nbsp;' => "\u00A0",
  }.freeze

  # Matches any HTML tag that is NOT br, sup, or sub
  DISALLOWED_TAG_PATTERN = /<\/?(?!(?:br|sup|sub)\b)[a-zA-Z][^>]*>/i

  def self.call(str)
    return '' if str.blank?

    result = str.dup

    # Phase 1: HTML entities
    HTML_ENTITY_MAP.each { |entity, replacement| result.gsub!(entity, replacement) }
    result.gsub!(/&#(\d+);/) { [::Regexp.last_match(1).to_i].pack('U') }
    result.gsub!(/&#x([0-9a-f]+);/i) { [::Regexp.last_match(1).hex].pack('U') }

    # Phase 2: Control characters
    result.gsub!(/[\x00-\x08\x0B-\x1F\x7F]/, '')
    result.gsub!("\t", '    ')
    result.gsub!("\n", '<br>')

    # Phase 3: TARIC markup (|| before | is critical - see class comment)
    result.gsub!('!1!', '<br>')
    result.gsub!('||', '<br>')
    result.gsub!('!X!', 'x')
    result.gsub!('!x!', 'x')
    result.gsub!('!o!', "\u00B0")
    result.gsub!('!O!', "\u00B0")
    result.gsub!('!>=!', '>=')
    result.gsub!('!<=!', '<=')
    result.gsub!('!%!', "\u2030")
    result.gsub!(/\$(.)/) { "<sup>#{::Regexp.last_match(1)}</sup>" }
    result.gsub!(/@(.)/) { "<sub>#{::Regexp.last_match(1)}</sub>" }
    result.tr!('|', "\u00A0")

    # Phase 4: HTML tag cleanup
    result.gsub!(/<p\s*\/?>/i, '<br>')
    result.gsub!(DISALLOWED_TAG_PATTERN, ' ')

    # Phase 5: Unicode normalisation
    UNICODE_SUPERSCRIPTS.each { |char, digit| result.gsub!(char, "<sup>#{digit}</sup>") }
    UNICODE_SUBSCRIPTS.each { |char, digit| result.gsub!(char, "<sub>#{digit}</sub>") }
    UNICODE_TO_ASCII.each { |char, replacement| result.gsub!(char, replacement) }

    # Phase 6: Cleanup
    unless result.valid_encoding?
      result = result.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
    end
    result.gsub!(/ {2,}/, ' ')
    result.strip
  end
end
