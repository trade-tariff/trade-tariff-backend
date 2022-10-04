class PreferenceCodeList
  class << self
    def all
      @preference_codes ||= JSON.load_file('data/preference_codes.json')

      @preference_codes.map do |pc|
        PreferenceCode.new(id: pc['id'], description: pc['description'])
      end
    end

    def get(id)
      all.find { |pc| pc['id'] == id.to_s }
    end
  end
end
