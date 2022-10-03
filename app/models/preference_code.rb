class PreferenceCode
  @@preference_codes = []

  def initialize
    return if @@preference_codes.any?
    puts 'Loading ...'
    @@preference_codes = JSON.load_file('data/preference_codes.json')
  end

  def all
    @@preference_codes
  end

  def gen
  end
end
