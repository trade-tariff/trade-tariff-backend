class FootnoteType < Sequel::Model
  plugin :oplog, primary_key: :footnote_type_id

  set_primary_key [:footnote_type_id]

  one_to_one :footnote_type_description, key: :footnote_type_id,
                                         primary_key: :footnote_type_id,
                                         eager_loader_key: :footnote_type_id

  one_to_many :footnotes

  delegate :description, to: :footnote_type_description
end
