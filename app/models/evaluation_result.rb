class EvaluationResult < Sequel::Model(Sequel[:evaluation_results].qualify(:uk))
  many_to_one :evaluation_run, key: :run_id

  IDENTITY_COLUMNS = %i[run_id source_id persona].freeze

  def self.ingest!(run:, source_type:, source_id:, persona:, attrs: {})
    payload = attrs.merge(run_id: run.id, source_type:, source_id:, persona:)
    values = new(payload).values
    update_payload = values.reject { |key, _| IDENTITY_COLUMNS.include?(key) }

    dataset
      .insert_conflict(target: IDENTITY_COLUMNS, update: update_payload)
      .returning
      .insert(values)
      .first
  end
end
