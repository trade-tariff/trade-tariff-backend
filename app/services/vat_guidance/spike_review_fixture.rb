module VatGuidance
  class SpikeReviewFixture
    REVIEW_MODE = ReviewDecisionContract::SYNTHETIC_MODE
    REVIEWER = 'synthetic:ai-1146-spike'.freeze
    REVIEWED_AT = '2026-08-19T12:00:00Z'.freeze

    def initialize(paths:, exclusions:, connection_proposals:)
      @paths = paths
      @exclusions = exclusions
      @connection_proposals = connection_proposals
    end

    def call
      {
        'review_mode' => REVIEW_MODE,
        'production_eligible' => false,
        'reviewer' => REVIEWER,
        'warning' => 'Synthetic decisions exercise the approval and composition contracts only. They are not HMRC or tax-content approval.',
        'quote_support_decisions' => quote_support_decisions,
        'pairing_decisions' => pairing_decisions,
      }
    end

  private

    attr_reader :paths, :exclusions, :connection_proposals

    def quote_support_decisions
      decisions = (paths + exclusions).map do |subject|
        decision(
          id: "quote-support:#{subject.fetch('id')}",
          subject_id: subject.fetch('id'),
          subject_sha256: ReviewDecisionContract.subject_sha256(subject),
        )
      end
      decisions.sort_by { |item| item.fetch('id') }
    end

    def pairing_decisions
      decisions = connection_proposals.map do |proposal|
        decision(
          id: "pairing:#{proposal.fetch('id')}",
          subject_id: proposal.fetch('id'),
          subject_sha256: proposal.fetch('subject_sha256'),
        )
      end
      decisions.sort_by { |item| item.fetch('id') }
    end

    def decision(id:, subject_id:, subject_sha256:)
      payload = {
        'id' => id,
        'subject_id' => subject_id,
        'subject_sha256' => subject_sha256,
        'status' => 'spike_approved',
        'review_mode' => REVIEW_MODE,
        'reviewer' => REVIEWER,
        'reviewed_at' => REVIEWED_AT,
        'rationale' => 'Synthetic positive decision used to exercise the fail-closed spike workflow.',
      }
      payload['decision_sha256'] = ReviewDecisionContract.decision_sha256(payload)
      payload
    end
  end
end
