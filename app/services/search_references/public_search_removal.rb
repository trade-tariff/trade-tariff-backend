module SearchReferences
  # The search reference index and search suggestions are rebuilt on a schedule.
  # Remove a reference straight away when it stops being a public search reference.
  class PublicSearchRemoval
    # previous_usage is nil when a deleted reference is re-created. Its old
    # suggestion may still be live, so it is removed if it comes back as fpo.
    def self.call(search_reference, previous_usage:)
      return unless search_reference.fpo?
      return if previous_usage == SearchReference::FPO_USAGE

      SearchSuggestion.search_reference_type.where(id: search_reference.id.to_s).delete
      TradeTariffBackend.search_client.delete(::Search::SearchReferenceIndex, search_reference)
    rescue OpenSearch::Transport::Transport::Errors::NotFound
      nil
    end
  end
end
