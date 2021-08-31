# frozen_string_literal: true

require 'csv'

module RulesOfOrigin
  class HeadingMappings
    SERVICES = %w[uk xi].freeze
    SUB_HEADING_FORMAT = %r{\A\d{6}\z}.freeze

    def initialize(source_file)
      @mappings = nil

      @source_file = Pathname.new(source_file)
      unless @source_file.extname == '.csv' && @source_file.file? && @source_file.exist?
        raise InvalidFile, 'Requires a path to a CSV file'
      end
    end

    def import
      raise AlreadyImported if @mappings

      @mappings = {}
      count = 0

      CSV.foreach(@source_file, headers: true) do |row|
        count += 1

        next unless row['scope'] == TradeTariffBackend.service
        if row['id_rule'].blank? || row['sub_heading'].blank? || row['scheme_code'].blank?
          raise InvalidFile, "Row #{count} is invalid - sub_heading or id_rule are blank"
        end

        @mappings[row['sub_heading']] ||= {}
        @mappings[row['sub_heading']][row['scheme_code']] ||= []
        @mappings[row['sub_heading']][row['scheme_code']] << row['id_rule'].to_i
      end

      @mappings.values.map(&:length).sum
    end

    def for_heading_and_schemes(heading, scheme_codes)
      schemes = @mappings[heading]
      return [] if schemes.nil?

      schemes.slice(*scheme_codes)
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
