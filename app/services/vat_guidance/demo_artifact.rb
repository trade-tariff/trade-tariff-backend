require 'json'

module VatGuidance
  class DemoArtifact
    InvalidArtifact = Class.new(StandardError)
    DEFAULT_PATH = Rails.root.join('data/vat_guidance/hmrc_poc.json').freeze
    NOTICE_JOURNEYS = {
      'notice-701-14-food-exceptions' => {
        title: 'VAT Notice 701/14 — food exceptions',
        description: 'Exercises the standalone food-exception path from VAT Notice 701/14.',
        path_count: 2,
        notice_number: '701/14',
        applicable_commodity_codes: %w[2005202000 2008939120 2008979890],
      },
      'notice-709-1-catering-reference-expanded' => {
        title: 'VAT Notice 709/1 — catering and food exceptions',
        description: 'Exercises the reference-expanded catering path and its VAT Notice 701/14 food-exception follow-up.',
        path_count: 3,
        notice_number: '709/1',
        applicable_commodity_codes: %w[2005202000 2008939120 2008979890],
      },
    }.freeze

    def initialize(path: DEFAULT_PATH)
      @path = path
    end

    def call
      artifact = JSON.parse(File.read(path))
      validate!(artifact)

      {
        'schema_version' => artifact.fetch('schema_version'),
        'ticket' => artifact.fetch('ticket'),
        'source_artifact_sha256' => artifact.fetch('content_sha256'),
        'service_position' => artifact.fetch('service_position'),
        'spike_status' => artifact.fetch('spike_status'),
        'summary' => artifact.fetch('summary'),
        'composed_commodity_journeys' => artifact.fetch('composed_commodity_journeys'),
        'notice_journeys' => build_notice_journeys(artifact),
      }
    rescue Errno::ENOENT, JSON::ParserError, KeyError => e
      raise InvalidArtifact, "VAT guidance demo artifact is unavailable: #{e.message}"
    end

  private

    attr_reader :path

    def build_notice_journeys(artifact)
      NOTICE_JOURNEYS.map do |journey_id, definition|
        paths = artifact.fetch('answer_paths').select { |answer_path| answer_path['journey_id'] == journey_id }
        validate_notice_paths!(paths, definition)

        {
          'id' => journey_id,
          'kind' => 'notice',
          'title' => definition.fetch(:title),
          'description' => definition.fetch(:description),
          'applicable_commodity_codes' => definition.fetch(:applicable_commodity_codes),
          'status' => 'spike_evidence_only',
          'review_mode' => 'pending_domain_review',
          'production_eligible' => false,
          'evidence_only' => true,
          'resolved_answer_paths' => paths.map { |answer_path| project_notice_route(answer_path) }.sort_by { |route| route.fetch('id') },
        }
      end
    end

    def validate_notice_paths!(paths, definition)
      notice_number = definition.fetch(:notice_number)
      expected_path_count = definition.fetch(:path_count)
      unless paths.size == expected_path_count
        raise InvalidArtifact, "VAT guidance demo artifact must contain #{expected_path_count} complete #{notice_number} paths"
      end

      valid = paths.all? do |answer_path|
        answer_path.dig('scope', 'notice_number') == notice_number &&
          answer_path.dig('terminal', 'type') == 'outcome' &&
          answer_path.dig('review', 'quote_support', 'status') == 'pending_domain_review'
      end
      raise InvalidArtifact, "VAT guidance demo artifact contains an unsafe #{notice_number} path" unless valid
    end

    def project_notice_route(answer_path)
      terminal = answer_path.fetch('terminal')
      {
        'id' => answer_path.fetch('id'),
        'steps' => answer_path.fetch('steps'),
        'resolution' => 'evidence_only_notice_comparison',
        'treatment' => terminal.fetch('treatment'),
        'additional_code' => nil,
        'measure_ids' => [],
        'connection_ids' => [],
        'terminal_evidence' => terminal.fetch('evidence'),
      }
    end

    def validate!(artifact)
      expected_hash = QuestionJourneyArtifactBuilder.content_sha256(artifact)
      status = artifact.fetch('spike_status')
      journeys = artifact.fetch('composed_commodity_journeys')

      raise InvalidArtifact, 'VAT guidance demo artifact hash is invalid' unless artifact['content_sha256'] == expected_hash
      raise InvalidArtifact, 'VAT guidance demo artifact is not AI-1146' unless artifact['ticket'] == 'AI-1146'
      raise InvalidArtifact, 'VAT guidance demo artifact is not simulation-ready' unless status['end_to_end_simulation_ready'] == true
      raise InvalidArtifact, 'VAT guidance demo artifact must remain runtime-unapproved' unless status['runtime_approved'] == false
      raise InvalidArtifact, 'VAT guidance demo artifact must remain production-unready' unless status['production_ready'] == false
      raise InvalidArtifact, 'VAT guidance demo artifact has no composed journeys' unless journeys.is_a?(Array) && journeys.any?
      return if journeys.all? { |journey| journey['production_eligible'] == false }

      raise InvalidArtifact, 'VAT guidance demo artifact contains a production-eligible journey'
    rescue KeyError => e
      raise InvalidArtifact, "VAT guidance demo artifact is incomplete: #{e.message}"
    end
  end
end
