require 'digest'

module VatGuidance
  class AnswerPathEnumerator
    EnumerationError = Class.new(StandardError)
    MAX_VISITS = 10_000

    def initialize(question_journeys)
      @question_journeys = question_journeys.deep_stringify_keys
    end

    def call
      paths = journeys.flat_map { |journey| enumerate_journey(journey) }
      exclusions = journeys.flat_map { |journey| enumerate_exclusions(journey) }

      ensure_unique_ids!(paths, 'answer paths')
      ensure_unique_ids!(exclusions, 'exclusions')

      { 'answer_paths' => paths.sort_by { |path| path.fetch('id') }, 'exclusions' => exclusions.sort_by { |item| item.fetch('id') } }
    end

  private

    attr_reader :question_journeys

    def journeys
      value = question_journeys['journeys']
      raise EnumerationError, 'question journey artifact must contain journeys' unless value.is_a?(Array)

      value
    end

    def enumerate_journey(journey)
      @journey = journey
      @questions = Array(journey['questions']).index_by { |question| question.fetch('id') }
      @outcomes = Array(journey['outcomes']).index_by { |outcome| outcome.fetch('id') }
      @visits = 0
      walk(journey.fetch('root_question_id'), [], [])
    ensure
      @journey = @questions = @outcomes = nil
    end

    def walk(question_id, visited_question_ids, steps)
      @visits += 1
      raise EnumerationError, "journey #{@journey.fetch('journey_id')} exceeds #{MAX_VISITS} visits" if @visits > MAX_VISITS
      raise EnumerationError, "journey #{@journey.fetch('journey_id')} contains a cycle at #{question_id}" if visited_question_ids.include?(question_id)

      question = @questions[question_id]
      raise EnumerationError, "journey #{@journey.fetch('journey_id')} targets missing question #{question_id}" unless question

      Array(question['answers']).flat_map do |answer|
        step = {
          'question_id' => question_id,
          'question' => question.fetch('prompt'),
          'answer_id' => answer.fetch('id'),
          'answer' => answer.fetch('label'),
          'relief_disposition' => answer['relief_disposition'],
          'evidence' => question.fetch('evidence'),
        }.compact
        next_steps = steps + [step]
        transition = answer.fetch('next')

        case transition.fetch('type')
        when 'question'
          walk(transition.fetch('id'), visited_question_ids + [question_id], next_steps)
        when 'outcome'
          [build_outcome_path(next_steps, transition.fetch('id'))]
        when 'fallthrough'
          [build_fallthrough_path(next_steps, transition)]
        else
          raise EnumerationError, "journey #{@journey.fetch('journey_id')} has an unsupported transition"
        end
      end
    end

    def build_outcome_path(steps, outcome_id)
      outcome = @outcomes[outcome_id]
      raise EnumerationError, "journey #{@journey.fetch('journey_id')} targets missing outcome #{outcome_id}" unless outcome

      terminal = {
        'type' => 'outcome',
        'id' => outcome_id,
        'treatment' => outcome.fetch('treatment'),
        'basis' => outcome.fetch('basis'),
        'evidence' => outcome.fetch('evidence'),
      }
      build_path(steps, terminal)
    end

    def build_fallthrough_path(steps, transition)
      terminal = {
        'type' => 'fallthrough',
        'id' => transition.fetch('id'),
        'reason' => transition.fetch('reason'),
        'trader_visible' => transition.fetch('trader_visible'),
      }
      build_path(steps, terminal)
    end

    def build_path(steps, terminal)
      subject = {
        'source_question_journeys_sha256' => question_journeys.fetch('content_sha256'),
        'journey_id' => @journey.fetch('journey_id'),
        'steps' => steps.map { |step| step.slice('question_id', 'answer_id') },
        'terminal' => terminal.slice('type', 'id', 'treatment'),
      }

      {
        'id' => "answer-path:#{sha256(subject)}",
        'subject_sha256' => sha256(subject),
        'journey_id' => @journey.fetch('journey_id'),
        'source_packet_id' => @journey.fetch('source_packet_id'),
        'scope' => @journey.fetch('scope'),
        'steps' => steps,
        'terminal' => terminal,
        'review' => review_for(terminal),
      }
    end

    def review_for(terminal)
      quote_review = {
        'status' => 'pending_domain_review',
        'decision_scope' => 'Does the cited guidance support this complete answer path and terminal?',
      }

      if terminal['type'] == 'fallthrough'
        return {
          'kind' => 'disposition',
          'status' => 'spike_recorded',
          'disposition' => 'composition_gate',
          'reason' => terminal.fetch('reason'),
          'quote_support' => quote_review,
        }
      end

      treatment = terminal.fetch('treatment')
      if treatment == 'standard'
        {
          'kind' => 'disposition',
          'status' => 'spike_recorded',
          'disposition' => 'explicit_standard_ending',
          'reason' => 'Standard treatment is the no-additional-code disposition, not a relief-measure connection.',
          'quote_support' => quote_review,
        }
      elsif connection_origin?
        {
          'kind' => 'connection_candidate',
          'status' => 'pending_domain_review',
          'treatment' => treatment,
          'additional_code' => QuestionJourneyContract::TREATMENTS.fetch(treatment).fetch('additional_code'),
          'measure_binding_status' => 'tariff_snapshot_required',
          'evidence_for' => terminal.fetch('evidence'),
          'evidence_against' => 'Review every declarable commodity reached by the candidate measure and record a plausible wrong-relief case before approval.',
          'quote_support' => quote_review,
        }
      else
        {
          'kind' => 'disposition',
          'status' => 'spike_recorded',
          'disposition' => prototype_disposition,
          'reason' => prototype_reason,
          'quote_support' => quote_review,
        }
      end
    end

    def connection_origin?
      @journey.dig('scope', 'type') == 'notice' && @journey['comparison_role'].blank?
    end

    def prototype_disposition
      @journey.dig('scope', 'type') == 'commodity' ? 'commodity_prototype_only' : 'comparison_evidence_only'
    end

    def prototype_reason
      if @journey.dig('scope', 'type') == 'commodity'
        'Commodity journeys validate the questions but are assembled from rule-path connections; they are never measure-connection origins.'
      else
        'The catering local/expanded pair demonstrates evidence expansion and cannot originate a duplicate relief connection.'
      end
    end

    def enumerate_exclusions(journey)
      Array(journey['exclusions']).map do |exclusion|
        subject = {
          'source_question_journeys_sha256' => question_journeys.fetch('content_sha256'),
          'journey_id' => journey.fetch('journey_id'),
          'exclusion_id' => exclusion.fetch('id'),
        }
        {
          'id' => "exclusion-path:#{sha256(subject)}",
          'subject_sha256' => sha256(subject),
          'journey_id' => journey.fetch('journey_id'),
          'source_packet_id' => journey.fetch('source_packet_id'),
          'scope' => journey.fetch('scope'),
          'exclusion' => exclusion,
          'review' => {
            'kind' => 'disposition',
            'status' => 'spike_recorded',
            'disposition' => 'assessment_or_apportionment_exclusion',
            'quote_support' => {
              'status' => 'pending_domain_review',
              'decision_scope' => 'Does the cited guidance support excluding this case from a single-treatment journey?',
            },
          },
        }
      end
    end

    def ensure_unique_ids!(items, label)
      ids = items.pluck('id')
      raise EnumerationError, "duplicate #{label}" unless ids.uniq.size == ids.size
    end

    def sha256(value)
      Digest::SHA256.hexdigest(QuestionJourneyArtifactBuilder.canonical_json(value))
    end
  end
end
