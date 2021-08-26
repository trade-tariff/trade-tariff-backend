# frozen_string_literal: true

module RulesOfOrigin
  class Rule
    include ActiveModel::Model

    attr_accessor :id_rule, :scheme_code, :heading, :description,
                  :quota_amount, :quota_unit, :rule, :alternate_rule

    validates :id_rule, presence: true, format: %r{\A\d+\z}
    validates :scheme_code, presence: true, format: %r{\A[a-zA-Z]+\z}
    validates :heading, presence: true
    validates :rule, presence: true
  end
end
