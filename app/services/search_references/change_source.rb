# frozen_string_literal: true

module SearchReferences
  # Readable labels for the paper trail whodunnit on search reference changes.
  module ChangeSource
    # Must match SearchReferencesTasks::BACKFILL_WHODUNNIT in lib/tasks/search_references.rake.
    BACKFILL_WHODUNNIT = "#{ClearInvalidSearchReferences::WHODUNNIT} (backfill)".freeze

    SYSTEM_LABELS = {
      ClearInvalidSearchReferences::WHODUNNIT => 'Automatic clean-up',
      BACKFILL_WHODUNNIT => 'Automatic clean-up (backfill)',
      FpoCsvImporter::DEFAULT_WHODUNNIT => 'FPO CSV import',
    }.freeze

    AUTOMATIC_REMOVAL_WHODUNNITS = [ClearInvalidSearchReferences::WHODUNNIT, BACKFILL_WHODUNNIT].freeze

    ADMIN_USER_LABEL = 'Admin user'

    # Admin sends the user's Cognito sub (a UUID) as X-Whodunnit. Basic auth is non-production only.
    ADMIN_UID = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/
    ADMIN_BASIC_AUTH_UID = 'basic_auth_user'

    module_function

    def admin_user?(whodunnit)
      whodunnit == ADMIN_BASIC_AUTH_UID || ADMIN_UID.match?(whodunnit.to_s)
    end

    def automatic_removal?(whodunnit)
      AUTOMATIC_REMOVAL_WHODUNNITS.include?(whodunnit)
    end

    # Unrecognised values are returned unchanged.
    def label(whodunnit)
      SYSTEM_LABELS.fetch(whodunnit) { admin_user?(whodunnit) ? ADMIN_USER_LABEL : whodunnit }
    end
  end
end
