require 'digest'

module VatGuidance
  module ReviewDecisionContract
    SYNTHETIC_MODE = 'synthetic_spike_fixture'.freeze
    AUTHORISED_MODE = 'authorised_human_review'.freeze
    SPIKE_APPROVAL = 'spike_approved'.freeze
    PRODUCTION_APPROVAL = 'approved'.freeze

    def self.subject_sha256(subject)
      review_subject = subject.deep_stringify_keys.except('review')
      Digest::SHA256.hexdigest(QuestionJourneyArtifactBuilder.canonical_json(review_subject))
    end

    def self.decision_sha256(decision)
      payload = decision.deep_stringify_keys.except('decision_sha256')
      Digest::SHA256.hexdigest(QuestionJourneyArtifactBuilder.canonical_json(payload))
    end

    def self.proposal_subject_sha256(proposal)
      subject = proposal.deep_stringify_keys.slice(
        'answer_path_subject_sha256',
        'answer_path_id',
        'journey_id',
        'treatment',
        'measure_snapshot',
        'evidence_for',
        'evidence_against',
      )
      Digest::SHA256.hexdigest(QuestionJourneyArtifactBuilder.canonical_json(subject))
    end
  end
end
