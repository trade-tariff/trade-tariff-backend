class DescriptionTrimFormatter
  def self.format(opts = {})
    raise ArgumentError, 'DescriptionFormatter expects :using arg to be a single value' if opts.keys.many?

    str = opts.values.first
    return '' if str.blank?

    str.gsub!('&nbsp;', ' ')
    str.tr!('|', ' ')
    str.gsub!('!1!', '')
    str.gsub!('!X!', '')
    str.gsub!('!x!', '')
    str.gsub!('!o!', '')
    str.gsub!('!O!', '')
    str.gsub!('!>=!', '')
    str.gsub!('!<=!', '')
    str.gsub!(/@(.)/) do
      ::Regexp.last_match(1).to_s
    end
    str.gsub!(/\$(.)/) do
      ::Regexp.last_match(1).to_s
    end
    str.strip
    str.html_safe
  end
end
