class PreferenceCode
  class << self
    def all
      @preference_codes ||= JSON.load_file('data/preference_codes.json')

      @preference_codes
    end

    def get(id)
      all.find { |e| e['id'] == id.to_s }
    end
  end
end
