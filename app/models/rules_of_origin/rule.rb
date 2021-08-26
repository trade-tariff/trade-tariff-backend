# frozen_string_literal: true

module RulesOfOrigin
  class Rule
    include ActiveModel::Model

    attr_accessor :id_rule, :scheme_code, :heading, :description,
                  :quota_amount, :quota_unit, :rule, :alternate_rule
  end
end
