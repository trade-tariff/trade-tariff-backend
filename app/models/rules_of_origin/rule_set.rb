# frozen_string_literal: true

require 'csv'

module RulesOfOrigin
  class RuleSet
    DEFAULT_SOURCE_PATH = Rails.root.join('lib/rules_of_origin').freeze
    DEFAULT_FILE = 'rules_of_origin_211124.csv'

    class << self
      def from_default_file
        new DEFAULT_SOURCE_PATH.join(DEFAULT_FILE)
      end
    end

    def initialize(source_file)
      @rules = nil

      @source_file = Pathname.new(source_file)
      unless @source_file.extname == '.csv' && @source_file.file? && @source_file.exist?
        raise InvalidFile, 'Requires a path to a CSV file'
      end
    end

    def import
      raise AlreadyImported if @rules

      @rules ||= {}

      CSV.foreach(@source_file, headers: true) do |row|
        next unless row['scope'] == 'both' || row['scope'] == TradeTariffBackend.service

        add_rule row['id_rule'].to_i, row.to_h.without('scope', 'id_rule')
      end

      @rules.length
    end

    def add_rule(id_rule, rule_data)
      @rules ||= {}
      @rules[id_rule] = rule_data
    end

    def id_rules
      @rules.keys
    end

    def rule(id_rule)
      rule = @rules[id_rule.to_i]

      ::RulesOfOrigin::Rule.new rule.merge(id_rule: id_rule.to_i) if rule
    end

    def rules_for_ids(id_rules)
      id_rules.map(&method(:rule)).compact
    end

    def invalid_rules
      [].tap do |invalid|
        @rules.each do |id_rule, rule|
          rule = ::RulesOfOrigin::Rule.new rule.merge(id_rule:)

          invalid << rule if rule.invalid?
        end
      end
    end

    class InvalidFile < RuntimeError; end

    class AlreadyImported < RuntimeError; end
  end
end
