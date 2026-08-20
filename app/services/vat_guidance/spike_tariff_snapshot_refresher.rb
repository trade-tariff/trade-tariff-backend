require 'digest'
require 'json'
require 'net/http'
require 'timeout'

module VatGuidance
  class SpikeTariffSnapshotRefresher
    RefreshError = Class.new(StandardError)
    CONNECTION_SCOPE = {
      '-1012552782' => %w[6506101000 6506108000],
      '-1012549006' => %w[9401800000],
      '-1012550499' => %w[2005202000],
      '-1012550520' => %w[2008939120 2008979890],
      '-1012986553' => %w[8407100010],
      '-1012984751' => %w[8409100010 8409100020 8409100090],
      '-1012980985' => %w[8424100011],
    }.freeze

    def initialize(seed_snapshot, retrieved_at:, fetcher: nil)
      @seed_snapshot = seed_snapshot.deep_stringify_keys
      @retrieved_at = retrieved_at
      @fetcher = fetcher || method(:read_tariff_url)
    end

    def call
      measures = seed_snapshot.fetch('measures').map { |measure| refresh_measure(measure) }
      validate_scope!(measures)
      inventory = connection_codes(measures).map { |code| inventory_entry(code, measures) }
      snapshot = {
        'schema_version' => TariffSnapshotContract::SCHEMA_VERSION,
        'snapshot_date' => seed_snapshot.fetch('snapshot_date'),
        'source' => 'UK Trade Tariff public API; independently captured origin and commodity responses',
        'retrieved_at' => retrieved_at,
        'production_approved' => false,
        'measures' => measures.sort_by { |measure| measure.fetch('measure_id') },
        'commodity_measure_inventory' => inventory,
      }
      snapshot['content_sha256'] = QuestionJourneyArtifactBuilder.content_sha256(snapshot)
      TariffSnapshotContract.new(snapshot).validate!
      snapshot
    rescue SocketError, Timeout::Error, JSON::ParserError => e
      raise RefreshError, "could not refresh tariff snapshot: #{e.message}"
    end

  private

    attr_reader :seed_snapshot, :retrieved_at, :fetcher

    def read_tariff_url(url)
      uri = URI.parse(url)
      unless uri.scheme == 'https' && uri.host == 'www.trade-tariff.service.gov.uk' && uri.path.start_with?('/uk/api/')
        raise RefreshError, 'refused non-Tariff snapshot source URL'
      end

      response = Net::HTTP.get_response(uri)
      raise RefreshError, "Tariff API returned #{response.code} for #{url}" unless response.is_a?(Net::HTTPSuccess)

      response.body
    end

    def refresh_measure(measure)
      body = fetcher.call(measure.fetch('source_url'))
      verify_origin_cohort!(measure, body)
      measure.slice(
        'measure_id', 'measure_type_id', 'additional_code', 'additional_code_id',
        'origin_goods_nomenclature', 'origin_type', 'effective_start_date', 'source_url',
        'declarable_commodity_codes'
      ).merge(
        'effective_end_date' => measure['effective_end_date'],
        'source_response_sha256' => Digest::SHA256.hexdigest(body),
        'declarable_commodity_codes' => measure.fetch('declarable_commodity_codes').uniq.sort,
        'cohort_sha256' => Digest::SHA256.hexdigest(
          QuestionJourneyArtifactBuilder.canonical_json(measure.fetch('declarable_commodity_codes').uniq.sort),
        ),
        'cohort_verified_from_origin_response' => true,
        'connection_commodity_codes' => CONNECTION_SCOPE.fetch(measure.fetch('measure_id')).sort,
      )
    end

    def verify_origin_cohort!(measure, body)
      response = JSON.parse(body)
      expected = measure.fetch('declarable_commodity_codes').sort
      observed = if measure.fetch('source_url').include?('/v2/measures/')
                   measure.fetch('connection_commodity_codes').sort
                 elsif measure.fetch('origin_type') == 'commodity'
                   [response.dig('data', 'attributes', 'goods_nomenclature_item_id')].compact
                 else
                   codes = []
                   response.fetch('included').each do |item|
                     if item['type'] == 'commodity' && item.dig('attributes', 'declarable') == true
                       codes << item.dig('attributes', 'goods_nomenclature_item_id')
                     end
                   end
                   codes.sort
                 end
      raise RefreshError, "origin cohort mismatch for #{measure.fetch('measure_id')}" unless observed == expected
    end

    def validate_scope!(measures)
      ids = measures.pluck('measure_id').sort
      raise RefreshError, 'connection scope does not match the pinned measure set' unless ids == CONNECTION_SCOPE.keys.sort

      measures.each do |measure|
        outside = measure.fetch('connection_commodity_codes') - measure.fetch('declarable_commodity_codes')
        raise RefreshError, "connection scope is outside cohort for #{measure.fetch('measure_id')}" if outside.any?
      end
    end

    def connection_codes(measures)
      measures.flat_map { |measure| measure.fetch('connection_commodity_codes') }.uniq.sort
    end

    def inventory_entry(code, measures)
      source_url = "https://www.trade-tariff.service.gov.uk/uk/api/commodities/#{code}"
      body = fetcher.call(source_url)
      response = JSON.parse(body)
      raise RefreshError, "#{code} is not a declarable UK commodity" unless response.dig('data', 'attributes', 'declarable') == true

      expected_measures = measures.select { |measure| measure.fetch('connection_commodity_codes').include?(code) }
      expected_ids = expected_measures.pluck('measure_id').sort
      live_ids = non_standard_vat_measure_ids(response)
      unless live_ids == expected_ids
        raise RefreshError, "non-standard VAT inventory mismatch for #{code}: expected #{expected_ids.join(', ')}, API returned #{live_ids.join(', ')}"
      end

      {
        'commodity_code' => code,
        'declarable' => true,
        'source_url' => source_url,
        'source_response_sha256' => Digest::SHA256.hexdigest(body),
        'applicable_non_standard_measure_ids' => expected_ids,
        'applicable_additional_codes' => expected_measures.pluck('additional_code').uniq.sort,
      }
    end

    def non_standard_vat_measure_ids(response)
      additional_codes = response.fetch('included').select { |item| item['type'] == 'additional_code' }
                                 .to_h { |item| [item.fetch('id'), item.dig('attributes', 'code')] }
      response.fetch('included').select { |item|
        item['type'] == 'measure' &&
          item.dig('attributes', 'vat') == true &&
          item.dig('attributes', 'import') == true &&
          item.dig('relationships', 'measure_type', 'data', 'id') == TariffSnapshotContract::VAT_MEASURE_TYPE &&
          TariffSnapshotContract::TREATMENT_CODES.include?(additional_codes[item.dig('relationships', 'additional_code', 'data', 'id')])
      }.pluck('id').sort
    end
  end
end
