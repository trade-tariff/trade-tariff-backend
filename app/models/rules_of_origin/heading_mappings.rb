# frozen_string_literal: true

require 'csv'

module RulesOfOrigin
  class HeadingMappings
    SERVICES = %w[uk xi both].freeze
    SUB_HEADING_FORMAT = %r{\A\d{6}\z}
    DEFAULT_SOURCE_PATH = Rails.root.join('lib/rules_of_origin').freeze
    DEFAULT_FILE = 'rules_to_commodities_211124.csv'

    class << self
      def from_default_file
        new DEFAULT_SOURCE_PATH.join(DEFAULT_FILE)
      end
    end

    def initialize(source_file)
      @mappings = nil

      @source_file = Pathname.new(source_file)
      unless @source_file.extname == '.csv' && @source_file.file? && @source_file.exist?
        raise InvalidFile, 'Requires a path to a CSV file'
      end
    end

    def import(skip_invalid_rows: false)
      raise AlreadyImported if @mappings

      @mappings = {}
      count = 1

      CSV.foreach(@source_file, headers: true) do |row|
        count += 1
        next unless row['scope'] == 'both' || row['scope'] == TradeTariffBackend.service

        if row['id_rule'].blank? || row['sub_heading'].blank? || row['scheme_code'].blank?
          next if skip_invalid_rows

          raise InvalidFile, "Row #{count} is invalid - sub_heading, scheme_code or id_rule are blank"
        end

        add_mapping row['sub_heading'], row['scheme_code'], row['id_rule']
      end

      @mappings.values.map(&:length).sum
    end

    def add_mapping(sub_heading, scheme_code, id_rule)
      @mappings ||= {}
      @mappings[sub_heading] ||= {}
      @mappings[sub_heading][scheme_code] ||= []
      @mappings[sub_heading][scheme_code] << id_rule.to_i
    end

    def heading_codes
      @mappings.keys
    end

    def for_heading_and_schemes(heading, scheme_codes)
      rules_for_heading_grouped_by_scheme_code = @mappings[heading]
      return {} if rules_for_heading_grouped_by_scheme_code.nil?

      rules_for_heading_grouped_by_scheme_code.slice(*scheme_codes)
    end

    def invalid_mappings
      invalid = {}
      row_number = 1 # Header row is skipped

      CSV.foreach(@source_file, headers: true) do |row|
        row_number += 1

        errors = []

        unless row['scope'].in?(SERVICES)
          errors << 'scope: unknown service'
        end

        if row['scheme_code'].blank?
          errors << 'scheme_code: cannot be blank'
        elsif !row['scheme_code'].match?(Rule::SCHEME_CODE_FORMAT)
          errors << 'scheme_code: invalid format'
        end

        if row['id_rule'].blank?
          errors << 'id_rule: cannot be blank'
        elsif !row['id_rule'].match?(Rule::ID_RULE_FORMAT)
          errors << 'id_rule: is not numeric'
        end

        if row['sub_heading'].blank?
          errors << 'sub_heading: cannot be blank'
        elsif !row['sub_heading'].match?(SUB_HEADING_FORMAT)
          errors << 'sub_heading: is not numeric'
        end

        if errors.any?
          invalid[row_number] = errors
        end
      end

      invalid
    end

    class InvalidFile < RuntimeError; end

    class AlreadyImported < RuntimeError; end
  end
end
