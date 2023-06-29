module BulkSearch
  class ReportGeneratorService
    MAX_SAMPLES = 100_000
    BATCH_SIZE = 1000
    CSV_FILE_PATH = 'DEC22COMCODEDESCRIPTION.csv'.freeze
    ALL_RESULTS_FILE = 'all_results.csv'.freeze
    ENCODINGS = [
      'Windows-1252:UTF-8',
      'UTF-16LE:BOM|UTF-8',
      'ISO-8859-1:UTF-8',
    ].freeze

    SAMPLE_COMMODITY_CODE_COLUMN = 0
    SAMPLE_DESCRIPTION_COLUMN = 1

    def initialize(
      sample_file_path: CSV_FILE_PATH,
      url: 'http://localhost:3000',
      max_samples: MAX_SAMPLES,
      batch_size: BATCH_SIZE
    )
      @sample_file_path = sample_file_path
      @url = url
      @max_samples = max_samples
      @batch_size = batch_size
    end

    def call
      raise ArgumentError, 'Unable to determine file encoding of sample CSV.' unless encoding

      Rails.logger.debug("Processing #{sample_file_path} with encoding #{encoding}")

      start = Time.zone.now

      all_input_descriptions = process_file
      expected_subheadings = find_expected_subheadings_for(all_input_descriptions)

      sampled_rows = CSV.read(ALL_RESULTS_FILE, headers: true)
      highest_scoring_results = highest_scoring_results_for(sampled_rows)

      elapsed_time = Time.zone.at(Time.zone.now - start).utc.strftime('%H:%M:%S')
      report_data = generate_input_data_for(highest_scoring_results, expected_subheadings)
      report_data[:elapsed_time] = elapsed_time

      Reporting::BulkSearch.generate(report_data)

      Rails.logger.debug("Elapsed time: #{elapsed_time}")
    end

    private

    attr_reader :file_path, :url, :max_samples, :batch_size, :sample_file_path

    def generate_input_data_for(highest_scoring_results, expected_subheadings)
      number_of_results = highest_scoring_results.count

      with_result = highest_scoring_results.reject do |result|
        result[:short_code].match?(/999999/)
      end
      matches = with_result.select do |result|
        expected_subheadings[result[:input_description]][:short_codes].include?(result[:short_code])
      end
      misses = with_result.reject do |result|
        expected_subheadings[result[:input_description]][:short_codes].include?(result[:short_code])
      end
      no_result = highest_scoring_results.select do |result|
        result[:short_code].match?(/999999/)
      end

      number_of_matches = matches.count
      number_of_misses = misses.count
      number_of_no_result = no_result.count

      percentage_of_matches = ((number_of_matches.to_f / number_of_results) * 100).round(2)

      {
        number_of_results:,
        number_of_matches:,
        number_of_misses:,
        number_of_no_result:,
        percentage_of_matches:,
        matches:,
        misses:,
        no_result:,
      }
    end

    def highest_scoring_results_for(sampled_rows)
      sampled_rows
        .group_by { |row| row['input_description'] }
        .transform_values { |grouped_results|
          highest_scoring = grouped_results.max_by { |result| result['score'].to_i }

          {
            input_description: highest_scoring['input_description'],
            short_code: highest_scoring['short_code'],
            score: highest_scoring['score'],
          }
        }
        .values
    end

    def encoding
      @encoding ||= ENCODINGS.find do |encoding|
        sample = File.read(sample_file_path, encoding:, lines: 5)
        sample.valid_encoding?
      end
    end

    def connection
      @connection ||= Faraday.new(url:)
    end

    def create_json(descriptions)
      data = descriptions.map do |desc|
        {
          type: 'bulk_search',
          attributes: {
            input_description: desc,
          },
        }
      end

      { data: }.to_json
    end

    def post_bulk_search(descriptions, index)
      payload = create_json(descriptions)

      response = connection.post do |req|
        req.url '/bulk_searches'
        req.headers['Content-Type'] = 'application/json'
        req.body = payload
      end

      job_id = response.headers['Location']

      Rails.logger.debug("Batch #{index} job ID: #{job_id}")

      retrieve_results(job_id)
    end

    def retrieve_results(job_id)
      loop do
        response = connection.get { |req| req.url "#{job_id}.csv" }

        case response.status
        when 200
          CSV.parse(response.body, headers: true) do |row|
            CSV.open(ALL_RESULTS_FILE, 'a') do |csv|
              csv << row
            end
          end
          break
        when 202
          sleep 5
        else
          raise "Unexpected response status: #{response.status}"
        end
      end
    end

    def process_file
      counter = 0
      total_sampled = 0
      all_input_descriptions = []
      input_descriptions = []
      index = 0

      CSV.open(ALL_RESULTS_FILE, 'w') do |csv|
        csv << %w[input_description goods_nomenclature_item_id producline_suffix goods_nomenclature_class short_code score]
      end

      CSV.foreach(sample_file_path, encoding:) do |row|
        next if row[SAMPLE_COMMODITY_CODE_COLUMN].nil?
        next if row[SAMPLE_DESCRIPTION_COLUMN].nil?

        commodity_code = row[SAMPLE_COMMODITY_CODE_COLUMN].gsub(/\s+/, '')
        original_description = row[SAMPLE_DESCRIPTION_COLUMN]
        input_description = row[SAMPLE_DESCRIPTION_COLUMN]
          .tr('-', ' ')
          .gsub(/[^a-zA-Z0-9 .]/, '')
          .downcase
          .strip

        all_input_descriptions << [commodity_code, input_description, original_description]

        total_sampled += 1
        input_descriptions << input_description
        counter += 1

        if counter == batch_size
          post_bulk_search(input_descriptions, index)
          counter = 0
          input_descriptions.clear
          index += 1
        end

        break if total_sampled >= max_samples
      end

      # Post the last batch if there are remaining descriptions
      post_bulk_search(input_descriptions, index) if counter.positive?

      all_input_descriptions
    end

    def find_expected_subheadings_for(input_descriptions)
      subheadings_by_commodity_code = {}
      subheadings_by_input_description = {}

      TimeMachine.now do
        input_descriptions.each do |commodity_code, _input_description, _original_description|
          subheadings_by_commodity_code[commodity_code] = nil
        end

        commodities_with_ancestors = Commodity
          .where(goods_nomenclature_item_id: subheadings_by_commodity_code.keys, producline_suffix: '80')
          .actual
          .eager(:ns_ancestors)
          .all

        commodities_with_ancestors = PresentedCommodity.wrap(commodities_with_ancestors)

        commodities_with_ancestors.map do |commodity|
          six_digit_goods_nomenclature, _reason = BulkSearch::HitAncestorFinderService.new(commodity, 6).call
          eight_digit_goods_nomenclature, _reason = BulkSearch::HitAncestorFinderService.new(commodity, 8).call

          if six_digit_goods_nomenclature
            subheadings_by_commodity_code[commodity.goods_nomenclature_item_id] = six_digit_goods_nomenclature.short_code
          elsif eight_digit_goods_nomenclature
            subheadings_by_commodity_code[commodity.goods_nomenclature_item_id] = eight_digit_goods_nomenclature.short_code
          end
        end

        input_descriptions.each do |commodity_code, input_description, _original_description|
          subheadings_by_input_description[input_description] ||= {}
          subheadings_by_input_description[input_description][:short_codes] ||= Set.new
          subheadings_by_input_description[input_description][:short_codes] << subheadings_by_commodity_code[commodity_code]
          subheadings_by_input_description[input_description][:input_description] = input_description
        end
      end

      subheadings_by_input_description
    end

    class PresentedCommodity < WrapDelegator
      def ancestors
        PresentedAncestor.wrap(ns_ancestors)
      end

      def short_code
        specific_system_short_code
      end

      def _score
        0
      end

      def _source
        self
      end

      def declarable?
        ns_declarable?
      end
    end

    class PresentedAncestor < WrapDelegator
      def short_code
        specific_system_short_code
      end

      def _score; end

      def declarable?
        ns_declarable?
      end
    end
  end
end
