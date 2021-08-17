class TransmissionComment < Sequel::Model
  plugin :oplog, primary_key: %i[comment_sid language_id]

  set_primary_key %i[comment_sid language_id]

  many_to_one :language
end
