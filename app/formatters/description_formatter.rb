class DescriptionFormatter
  def self.format(opts = {})
    raise ArgumentError, 'DescriptionFormatter expects :using arg to be a single value' if opts.keys.many?

    str = opts.values.first
    return '' if str.blank?

    str.gsub!('|%', '%')
    str.gsub!(160.chr('UTF-8'), ' ')
    str.gsub!(/(\d)\s+%/, '\1%')
    str.gsub!('-|', "\n-")
    str.gsub!('|', '&nbsp;')
    str.gsub!('!1!', '<br />')
    str.gsub!(/&(?!#|nbsp)/, '&amp;')
    str.gsub!('!X!', '&times;')
    str.gsub!('!x!', '&times;')
    str.gsub!('!o!', '&deg;')
    str.gsub!('!O!', '&deg;')
    str.gsub!('!>=!', '&ge;')
    str.gsub!('!<=!', '&le;')
    str.gsub!(/\n\s*\n/, '<br/>')
    str.gsub!("\n", '<br/>')
    if TradeTariffBackend.uk?
      str.gsub!(/izing/i, 'ising')
      str.gsub!(/ization/i, 'isation')
      str.gsub!(/ized/i, 'ised')
      str.gsub!(/(\d),(\d)/, '\1.\2')
    end
    str.gsub!(/@(.)/) do
      "<sub>#{::Regexp.last_match(1)}</sub>"
    end
    str.gsub!(/\$(.)/) do
      "<sup>#{::Regexp.last_match(1)}</sup>"
    end
    str.gsub!(/<sub>([a-z])<\/sub>/i, '@\1')
    str.gsub!(/<br>(\s+)?<li>/, '<li>')
    str.gsub!(/<br><br><ul>/, '<ul>')
    str.gsub!(/<br><\/ul><br>/, '</ul>')
    str.gsub!(/<br>(\s+)?<\/ul>/, '</ul>')
    str.gsub!(/(<br>){3,}/, '<br><br>')

    str.strip
    str.html_safe
  end
end
