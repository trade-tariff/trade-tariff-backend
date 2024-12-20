module CustomRegex
  def cas_number_regex
    # Extract the CAS number from a string
    # - may be just the CAS number alone, e.g. `10310-21-1`
    # - optional leading 'cas', with or without spaces after, e.g. `cas 10310-21-1`
    # - optional other text between the leading 'cas' and the CAS number. e.g. `cas rn 10310-21-1`
    # - optional other text before and/or after the CAS number. e.g. `cas rn blah 10310-21-1foobar biz baz   other text`
    # - additional digits after the CAS number are ignored. Note: CAS numbers always end in a dash, then a single digit (`-\d{1}`) e.g. `10310-21-1684984654687` is interpreted as `10310-21-1`
    /\A(?:cas\s*.*?\s*)?(\d+-\d+-\d{1}).*\z/i
  end

  def cus_number_regex
    # Seven digits, followed by a hyphen, followed by one digit.
    /\A\d{7}-\d\z/
  end

  def no_alpha_regex
    # entire strings that do not contain any alphabetic characters
    /^(?!.*[A-Za-z]+).*$/
  end

  def digit_regex
    /\d+/
  end

  def ignore_brackets_regex
    # ignore [ and ] characters, e.g., to avoid range searches
    /(\[|\])/
  end
end
