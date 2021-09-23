# frozen_string_literal: true

module RulesOfOrigin
  class Rule
    include ActiveModel::Model
    include ActiveModel::Attributes

    ID_RULE_FORMAT = %r{\A\d+\z}.freeze
    SCHEME_CODE_FORMAT = %r{\A[a-zA-Z\-]+\z}.freeze

    attribute :id_rule
    attribute :scheme_code
    attribute :heading
    attribute :description
    attribute :quota_amount
    attribute :quota_unit
    attribute :rule
    attribute :alternate_rule

    validates :id_rule, presence: true, format: ID_RULE_FORMAT
    validates :scheme_code, presence: true, format: SCHEME_CODE_FORMAT
    validates :heading, presence: true

    def ==(other)
      id_rule.present? &&
        other.respond_to?(:id_rule) &&
        other.id_rule == id_rule
    end
  end
end
