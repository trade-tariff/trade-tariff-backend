require 'date'
require 'digest'
require 'time'
require 'uri'

module VatGuidance
  class TariffSnapshotContract
    ValidationError = Class.new(StandardError)
    SCHEMA_VERSION = 2
    VAT_MEASURE_TYPE = '305'.freeze
    TREATMENT_CODES = %w[VATR VATZ VATE].freeze
    TOP_LEVEL_KEYS = %w[
      schema_version
      snapshot_date
      source
      retrieved_at
      production_approved
      measures
      commodity_measure_inventory
      content_sha256
    ].freeze
    MEASURE_KEYS = %w[
      measure_id
      measure_type_id
      additional_code
      additional_code_id
      origin_goods_nomenclature
      origin_type
      effective_start_date
      effective_end_date
      source_url
      source_response_sha256
      declarable_commodity_codes
      cohort_sha256
      cohort_verified_from_origin_response
      connection_commodity_codes
    ].freeze
    INVENTORY_KEYS = %w[
      commodity_code
      declarable
      source_url
      source_response_sha256
      applicable_non_standard_measure_ids
      applicable_additional_codes
    ].freeze

    def initialize(snapshot)
      @snapshot = snapshot.deep_stringify_keys
    end

    def validate!
      exact_keys!(snapshot, TOP_LEVEL_KEYS, 'snapshot')
      raise ValidationError, 'unsupported tariff snapshot schema' unless snapshot['schema_version'] == SCHEMA_VERSION
      raise ValidationError, 'tariff snapshot must not be production approved' unless snapshot['production_approved'] == false

      snapshot_date = parse_date!(snapshot.fetch('snapshot_date'), 'snapshot date')
      raise ValidationError, 'tariff snapshot date cannot be in the future' if snapshot_date > Date.current

      validate_timestamp!(snapshot.fetch('retrieved_at'))

      measures = snapshot.fetch('measures')
      inventory = snapshot.fetch('commodity_measure_inventory')
      raise ValidationError, 'tariff snapshot measures must be a non-empty array' unless measures.is_a?(Array) && measures.any?
      raise ValidationError, 'commodity measure inventory must be a non-empty array' unless inventory.is_a?(Array) && inventory.any?

      measures.each { |measure| validate_measure!(measure, snapshot_date) }
      inventory.each { |entry| validate_inventory!(entry) }
      ensure_unique!(measures.pluck('measure_id'), 'measure ids')
      ensure_unique!(inventory.pluck('commodity_code'), 'inventory commodity codes')
      validate_inventory_matches_measures!(measures, inventory)
      true
    end

  private

    attr_reader :snapshot

    def validate_measure!(measure, snapshot_date)
      exact_keys!(measure, MEASURE_KEYS, "measure #{measure['measure_id']}")
      raise ValidationError, 'VAT measure id must be an integer string' unless measure['measure_id'].match?(/\A-?\d+\z/)
      raise ValidationError, "measure #{measure['measure_id']} is not UK VAT measure type 305" unless measure['measure_type_id'] == VAT_MEASURE_TYPE
      raise ValidationError, "measure #{measure['measure_id']} has unsupported additional code" unless TREATMENT_CODES.include?(measure['additional_code'])
      raise ValidationError, "measure #{measure['measure_id']} has no additional-code identity" unless measure['additional_code_id'].match?(/\A-?\d+\z/)

      validate_code!(measure['origin_goods_nomenclature'], 'origin goods nomenclature')
      raise ValidationError, "measure #{measure['measure_id']} has unsupported origin type" unless %w[commodity subheading heading].include?(measure['origin_type'])

      start_date = parse_date!(measure['effective_start_date'], 'measure effective start date')
      end_date = measure['effective_end_date'] && parse_date!(measure['effective_end_date'], 'measure effective end date')
      raise ValidationError, "measure #{measure['measure_id']} is not active on snapshot date" if start_date > snapshot_date || (end_date && end_date < snapshot_date)

      validate_tariff_url!(measure['source_url'])
      validate_sha256!(measure['source_response_sha256'], 'measure source response')

      codes = measure.fetch('declarable_commodity_codes')
      raise ValidationError, "measure #{measure['measure_id']} has no declarable cohort" unless codes.is_a?(Array) && codes.any?

      codes.each { |code| validate_code!(code, 'declarable commodity') }
      raise ValidationError, "measure #{measure['measure_id']} cohort must be sorted and unique" unless codes == codes.uniq.sort

      expected_cohort_hash = Digest::SHA256.hexdigest(QuestionJourneyArtifactBuilder.canonical_json(codes))
      raise ValidationError, "measure #{measure['measure_id']} cohort evidence hash is invalid" unless measure['cohort_sha256'] == expected_cohort_hash
      unless measure['cohort_verified_from_origin_response'] == true
        raise ValidationError, "measure #{measure['measure_id']} cohort was not verified from its origin response"
      end

      connection_codes = measure.fetch('connection_commodity_codes')
      raise ValidationError, "measure #{measure['measure_id']} has no Spike connection scope" unless connection_codes.is_a?(Array) && connection_codes.any?

      connection_codes.each { |code| validate_code!(code, 'connection commodity') }
      unless connection_codes == connection_codes.uniq.sort && (connection_codes - codes).empty?
        raise ValidationError, "measure #{measure['measure_id']} connection scope must be a sorted subset of its full cohort"
      end
    end

    def validate_inventory!(entry)
      exact_keys!(entry, INVENTORY_KEYS, "inventory #{entry['commodity_code']}")
      validate_code!(entry['commodity_code'], 'inventory commodity')
      raise ValidationError, "inventory #{entry['commodity_code']} must be declarable" unless entry['declarable'] == true

      validate_tariff_url!(entry['source_url'])
      validate_sha256!(entry['source_response_sha256'], 'inventory source response')
      ids = entry['applicable_non_standard_measure_ids']
      codes = entry['applicable_additional_codes']
      raise ValidationError, "inventory #{entry['commodity_code']} has no non-standard VAT measures" unless ids.is_a?(Array) && ids.any?
      raise ValidationError, "inventory #{entry['commodity_code']} measure ids must be sorted and unique" unless ids == ids.uniq.sort
      raise ValidationError, "inventory #{entry['commodity_code']} additional codes must be sorted and unique" unless codes.is_a?(Array) && codes == codes.uniq.sort
      raise ValidationError, "inventory #{entry['commodity_code']} has unsupported additional code" unless (codes - TREATMENT_CODES).empty?
    end

    def validate_inventory_matches_measures!(measures, inventory)
      measure_index = measures.index_by { |measure| measure.fetch('measure_id') }
      expected = Hash.new { |hash, code| hash[code] = [] }
      measures.each do |measure|
        measure.fetch('connection_commodity_codes').each { |code| expected[code] << measure.fetch('measure_id') }
      end
      actual = inventory.to_h { |entry| [entry.fetch('commodity_code'), entry.fetch('applicable_non_standard_measure_ids')] }
      expected.transform_values!(&:sort)
      raise ValidationError, 'commodity inventory does not independently match measure cohorts' unless actual == expected.sort.to_h

      inventory.each do |entry|
        expected_codes = entry.fetch('applicable_non_standard_measure_ids').map { |id|
          measure = measure_index[id]
          raise ValidationError, "inventory references unknown measure #{id}" unless measure

          measure.fetch('additional_code')
        }.uniq.sort
        unless entry.fetch('applicable_additional_codes') == expected_codes
          raise ValidationError, "inventory #{entry.fetch('commodity_code')} additional codes do not match its measures"
        end
      end
    end

    def exact_keys!(value, expected, label)
      raise ValidationError, "#{label} must be an object" unless value.is_a?(Hash)
      return if value.keys.sort == expected.sort

      raise ValidationError, "#{label} has unexpected or missing fields"
    end

    def ensure_unique!(values, label)
      raise ValidationError, "duplicate #{label}" unless values.uniq.size == values.size
    end

    def validate_code!(value, label)
      raise ValidationError, "#{label} must be a ten-digit code" unless value.is_a?(String) && value.match?(/\A\d{10}\z/)
    end

    def validate_sha256!(value, label)
      raise ValidationError, "#{label} hash is invalid" unless value.is_a?(String) && value.match?(/\A[0-9a-f]{64}\z/)
    end

    def validate_tariff_url!(value)
      uri = URI.parse(value)
      return if uri.scheme == 'https' && uri.host == 'www.trade-tariff.service.gov.uk' && uri.path.start_with?('/uk/api/')

      raise ValidationError, 'tariff source URL is not an allowlisted UK Tariff API URL'
    rescue URI::InvalidURIError
      raise ValidationError, 'tariff source URL is invalid'
    end

    def parse_date!(value, label)
      Date.iso8601(value)
    rescue Date::Error, TypeError
      raise ValidationError, "#{label} must be an ISO date"
    end

    def validate_timestamp!(value)
      Time.iso8601(value)
    rescue ArgumentError, TypeError
      raise ValidationError, 'retrieved_at must be an ISO timestamp'
    end
  end
end
