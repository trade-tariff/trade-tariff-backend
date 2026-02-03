class ExtractBottomJson
  def self.call(text)
    return {} if text.to_s.blank?

    # Try direct parse first (clean JSON response)
    JSON.parse(text)
  rescue JSON::ParserError
    extract_from_end(text)
  end

  def self.extract_from_end(text)
    # Find the last closing bracket - that's where our JSON ends
    end_idx = [text.rindex('}'), text.rindex(']')].compact.max
    return {} unless end_idx

    # Try parsing from each opening bracket position, starting from earliest
    # This handles nested structures correctly
    opening = text[end_idx] == '}' ? '{' : '['
    start_positions = find_all_positions(text, opening, end_idx)

    start_positions.each do |start_idx|
      result = try_parse(text[start_idx..end_idx])
      return result if result
    end

    {}
  end

  def self.find_all_positions(text, char, before_idx)
    positions = []
    idx = 0
    while (found = text.index(char, idx)) && found <= before_idx
      positions << found
      idx = found + 1
    end
    positions
  end

  def self.try_parse(json_text)
    JSON.parse(json_text)
  rescue JSON::ParserError
    nil
  end

  private_class_method :extract_from_end, :find_all_positions, :try_parse
end
