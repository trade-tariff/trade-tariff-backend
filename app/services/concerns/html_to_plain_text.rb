module HtmlToPlainText
private

  def html_to_plain_text(text)
    with_line_breaks = text.to_s.gsub(%r{<br\s*/?>}i, "\n")
    sanitized_text = html_sanitizer.sanitize(with_line_breaks)
    CGI.unescapeHTML(sanitized_text)
  end

  def html_sanitizer
    @html_sanitizer ||= Rails::HTML5::FullSanitizer.new
  end
end
