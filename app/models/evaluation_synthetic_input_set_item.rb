# One synthetic ATaR frozen into a set, at the moment the set was created. query/oracle_text/expected_code are
# copied from the synthetic ATaR then, not read from it again later -- a later import can update an
# existing synthetic ATaR in place (TariffKnowledge::SyntheticAtarImporter matches on
# real_user_search), and a set that already scored against it must not silently change meaning.
class EvaluationSyntheticInputSetItem < Sequel::Model(Sequel[:evaluation_synthetic_input_set_items].qualify(:uk))
  plugin :validation_helpers

  many_to_one :evaluation_synthetic_input_set, key: :set_id

  def validate
    super
    validates_presence %i[set_id synthetic_atar_id query oracle_text expected_code]
  end
end
