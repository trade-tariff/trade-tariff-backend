class AdditionalCodeTypeDescription < Sequel::Model
  plugin :oplog, primary_key: %i[additional_code_type_id language_id], materialized: true

  set_primary_key %i[additional_code_type_id language_id]

  many_to_one :additional_code_type, key: :additional_code_type_id
  many_to_one :language, key: :language_id, primary_key: :language_id
end
