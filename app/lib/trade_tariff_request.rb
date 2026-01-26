class TradeTariffRequest < ActiveSupport::CurrentAttributes
  attribute :green_lanes,
            :time_machine_now,
            # Controls how TimeMachine filters associated records in queries.
            # When false/nil: associations use the global time_machine_now timestamp
            # When true: associations use the parent record's validity period
            # This is critical for indexing - when indexing historical records, we want
            # associations that were valid during that record's lifetime, not at an arbitrary point in time
            :time_machine_relevant,
            :meursing_additional_code_id,
            # Controls whether label fields (known_brands, colloquial_terms, synonyms)
            # are included in search suggestion queries
            :search_labels_enabled
end
