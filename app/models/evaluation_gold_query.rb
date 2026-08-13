class EvaluationGoldQuery < Sequel::Model(Sequel[:evaluation_gold_queries].qualify(:uk))
  IDENTITY_COLUMNS = %i[source_type source_id persona].freeze

  plugin :validation_helpers

  def validate
    super
    validates_presence %i[source_type source_id persona query expected_code]
  end
end
