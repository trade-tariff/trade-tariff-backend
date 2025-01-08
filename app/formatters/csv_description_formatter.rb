class CsvDescriptionFormatter
  def self.format(opts = {})
    raise ArgumentError, 'CsvDescriptionFormatter expects :using arg to be a single value' if opts.keys.many?

    str = opts.values.first
    return '' if str.blank?

    str.gsub!(/&nbsp;|\u00A0/, ' ')  # Non-breaking space to regular space
    str.gsub!(/\u{00B1}/, '±')
    str.gsub!(/<\/?(br|sub)(\s*\/)?>/, ' ') # Remove html tags, including self-closing tags
    str.gsub!(/&times;/, 'x')
    str.gsub!(/&deg;/, '°')

    # Match html superscript tags and sub them for their plain text equivalent char
    str.gsub!(/<sup>-(?=<\/sup>)<\/sup>/, '⁻')
    str.gsub!(/<sup>(\d+)<\/sup>/) do |match|
      superscripts = { '0' => '⁰', '1' => '¹', '2' => '²', '3' => '³', '4' => '⁴', '5' => '⁵', '6' => '⁶', '7' => '⁷', '8' => '⁸', '9' => '⁹' }

      match_data = /<sup>(-?\d+)<\/sup>/.match(match)
      number = match_data[1]
      result = number.chars.map { |char| superscripts[char] }.join

      result
    end

    str.strip
    str.html_safe
  end
end
