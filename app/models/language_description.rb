class LanguageDescription < Sequel::Model
  plugin :oplog, primary_key: %i[language_id language_code_id]

  set_primary_key %i[language_id language_code_id]
end
