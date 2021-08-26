# frozen_string_literal: true

require 'csv'

module RulesOfOrigin
  class HeadingMappings
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

    class InvalidFile < RuntimeError; end

    class AlreadyImported < RuntimeError; end
  end
end
