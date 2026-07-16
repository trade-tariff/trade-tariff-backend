module Search
  module Instrumentation
    module NoteEvidenceEvents
      def note_evidence_evaluated(request_id:, query:, effective_query:, iteration:, attempt_number:, operation:, enabled:, diagnostics:)
        instrument(
          'note_evidence_evaluated',
          request_id:,
          search_type: 'interactive',
          query:,
          effective_query:,
          iteration:,
          attempt_number:,
          operation:,
          note_evidence_enabled: enabled,
          note_evidence_status: diagnostics[:status],
          considered_note_count: diagnostics[:considered_note_count],
          considered_evidence_count: diagnostics[:considered_evidence_count],
          selected_note_count: diagnostics[:selected_note_count],
          selected_evidence_count: diagnostics[:selected_evidence_count],
          omitted_evidence_count: diagnostics[:omitted_evidence_count],
          logged_omitted_evidence_count: diagnostics[:logged_omitted_evidence_count],
          omitted_evidence_truncated: diagnostics[:omitted_evidence_truncated],
          details: diagnostics,
        )
      end
    end
  end
end
