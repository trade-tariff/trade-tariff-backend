# frozen_string_literal: true

module RulesOfOrigin
  class Rule
    include ActiveModel::Model

    ID_RULE_FORMAT = %r{\A\d+\z}.freeze
    SCHEME_CODE_FORMAT = %r{\A[a-zA-Z\-]+\z}.freeze

    attr_accessor :id_rule, :scheme_code, :heading, :description,
                  :quota_amount, :quota_unit, :rule, :alternate_rule

    validates :id_rule, presence: true, format: ID_RULE_FORMAT
    validates :scheme_code, presence: true, format: SCHEME_CODE_FORMAT
    validates :heading, presence: true
    validates :rule, presence: true
  end
end
