class FootnoteDescription < Sequel::Model
  include Formatter

  plugin :time_machine
  plugin :oplog, primary_key: %i[footnote_description_period_sid
                                 footnote_id
                                 footnote_type_id]

  set_primary_key %i[footnote_description_period_sid footnote_id footnote_type_id]

  custom_format :formatted_description, with: DescriptionFormatter,
                                        using: :description

  dataset_module do
    def with_fuzzy_description(description)
      where(Sequel.ilike(:description, "%#{description}%"))
    end
  end
end
