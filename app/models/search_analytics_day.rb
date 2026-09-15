# frozen_string_literal: true

# A row is published only after a complete collection. Failed attempts live separately.
class SearchAnalyticsDay < Sequel::Model
  DEFINITION_VERSION = 4
end
