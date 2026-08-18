class EvaluationGoldQuery < Sequel::Model(Sequel[:evaluation_gold_queries].qualify(:uk))
  IDENTITY_COLUMNS = %i[source_type source_id persona].freeze

  plugin :validation_helpers

  def validate
    super
    validates_presence %i[source_type source_id persona query expected_code]
  end

  # expected_code is stored at whatever granularity the source ruling actually published
  # (ATaR commodity codes are 6, 8, or 10 digits — not all rulings classify to a full
  # 10-digit leaf) — it is NEVER right-padded here. A consumer doing exact-match scoring
  # against a 10-digit goods_nomenclature_item_id must check this first: right-padding a
  # short code themselves to force a 10-digit comparison can land on a non-declarable
  # intermediate node with multiple declarable descendants, silently scoring against the
  # wrong target. expected_code_digits makes that granularity explicit on the API
  # response instead of leaving a consumer to infer it from String#length themselves.
  def expected_code_digits
    expected_code&.length
  end
end
