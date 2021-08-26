# frozen_string_literal: true

require 'csv'

module RulesOfOrigin
  class RuleSet
    include ActiveModel::Model

    def initialize(source_file)
      @rules = nil

      @source_file = Pathname.new(source_file)
      unless @source_file.extname == '.csv' && @source_file.file? && @source_file.exist?
        raise InvalidRulesFile, 'Requires a path to a CSV file'
      end
    end

    def import
      raise AlreadyImported if @rules

      @rules = {}

      CSV.foreach(@source_file, headers: true) do |row|
        next unless row['scope'] == TradeTariffBackend.service

        @rules[row['id_rule']] = row.to_h.without('scope', 'id_rule')
      end

      @rules.length
    end

    def rule(id_rule)
      rule = @rules[id_rule]

      Rule.new rule.merge(id_rule: id_rule) if rule
    end

    def invalid_rules
      [].tap do |invalid|
        @rules.each do |id_rule, rule|
          rule = Rule.new rule.merge(id_rule: id_rule)

          invalid << rule if rule.invalid?
        end
      end
    end

    class InvalidRulesFile < RuntimeError; end

    class AlreadyImported < RuntimeError; end
  end
end
