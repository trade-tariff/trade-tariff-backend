# frozen_string_literal: true

# Evaluates the CloudWatch Logs JSON filter subset used by backend degradation
# alarms against a parsed log event. This is test infrastructure for the
# terraform filter <-> logger contract, not production code.
module CloudWatchJsonFilter
  CLAUSE = /
    \$\.(?<path>[A-Za-z0-9_.]+)\s*
    (?<op>>=|<=|!=|=|>|<)\s*
    (?<value>"[^"]*"|\*|-?\d+(?:\.\d+)?)
  /x

module_function

  def matches?(pattern, event)
    clauses(pattern).all? { |clause| match_clause?(clause, event) }
  end

  def clauses(pattern)
    body = pattern.to_s.strip.delete_prefix('{').delete_suffix('}').strip
    body.split(/\s*&&\s*/).map do |raw|
      match = CLAUSE.match(raw.strip)
      raise ArgumentError, "unsupported CloudWatch JSON filter clause: #{raw.inspect}" unless match

      {
        path: match[:path],
        op: match[:op],
        value: parse_value(match[:value]),
      }
    end
  end

  def parse_value(raw)
    return :exists if raw == '*'
    return raw[1..-2] if raw.start_with?('"') && raw.end_with?('"')

    raw.include?('.') ? Float(raw) : Integer(raw)
  end

  def match_clause?(clause, event)
    actual = lookup(event, clause[:path])
    expected = clause[:value]

    case clause[:op]
    when '='
      expected == :exists ? !actual.nil? : values_equal?(actual, expected)
    when '!='
      expected == :exists ? actual.nil? : !values_equal?(actual, expected)
    when '>=', '<=', '>', '<'
      comparable?(actual, expected) && actual.public_send(clause[:op], expected)
    end
  end

  def lookup(event, path)
    path.split('.').reduce(event) do |current, key|
      break if current.nil?

      if current.is_a?(Hash)
        current[key] || current[key.to_sym]
      end
    end
  end

  def values_equal?(actual, expected)
    actual == expected || (actual.is_a?(Numeric) && expected.is_a?(Numeric) && actual == expected)
  end

  def comparable?(actual, expected)
    actual.is_a?(Numeric) && expected.is_a?(Numeric)
  end
end
