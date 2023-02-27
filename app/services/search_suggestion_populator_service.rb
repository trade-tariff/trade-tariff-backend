class SearchSuggestionPopulatorService
  def call
    SearchSuggestion.unrestrict_primary_key
    Api::V2::SuggestionsService.new.perform.each do |suggestion|
      SearchSuggestion.find_or_create(
        id: suggestion.id.to_s,
        value: suggestion.value.to_s,
      )
    end
    SearchSuggestion.restrict_primary_key
  end
end
