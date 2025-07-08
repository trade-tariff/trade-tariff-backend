class Footnote < Sequel::Model
  plugin :time_machine
  plugin :oplog, primary_key: %i[footnote_type_id footnote_id]

  set_primary_key %i[footnote_type_id footnote_id]

  many_to_many :footnote_descriptions, join_table: :footnote_description_periods,
                                       left_primary_key: %i[footnote_type_id footnote_id],
                                       left_key: %i[footnote_type_id footnote_id],
                                       right_key: %i[footnote_description_period_sid
                                                     footnote_type_id
                                                     footnote_id],
                                       right_primary_key: %i[footnote_description_period_sid
                                                             footnote_type_id
                                                             footnote_id],
                                       graph_use_association_block: true do |ds|
    ds.with_actual(FootnoteDescriptionPeriod)
      .order(Sequel.desc(:footnote_description_periods__validity_start_date))
  end

  def footnote_description
    footnote_descriptions.first
  end

  one_to_one :footnote_type, primary_key: :footnote_type_id,
                             key: :footnote_type_id

  one_to_many :footnote_description_periods, primary_key: %i[footnote_type_id
                                                             footnote_id],
                                             key: %i[footnote_type_id
                                                     footnote_id]
  many_to_many :measures, join_table: :footnote_association_measures,
                          left_key: %i[footnote_type_id footnote_id],
                          right_key: [:measure_sid]

  one_to_many :footnote_association_goods_nomenclatures, key: %i[footnote_type footnote_id],
                                                         primary_key: %i[footnote_id footnote_type_id]
  many_to_many :goods_nomenclatures, join_table: :footnote_association_goods_nomenclatures,
                                     left_key: %i[footnote_type footnote_id],
                                     right_key: [:goods_nomenclature_sid]

  one_to_many :footnote_association_erns, key: %i[footnote_type footnote_id],
                                          primary_key: %i[footnote_type_id footnote_id]
  many_to_many :export_refund_nomenclatures, join_table: :footnote_association_erns,
                                             left_key: %i[footnote_type footnote_id],
                                             right_key: [:export_refund_nomenclature_sid]
  one_to_many :footnote_association_additional_codes, key: %i[footnote_type_id footnote_id],
                                                      primary_key: %i[footnote_id footnote_type_id]
  many_to_many :additional_codes, join_table: :footnote_association_additional_codes,
                                  left_key: %i[footnote_type_id footnote_id],
                                  right_key: [:additional_code_sid]
  many_to_many :meursing_headings, join_table: :footnote_association_meursing_headings,
                                   left_key: %i[footnote_type footnote_id],
                                   right_key: %i[meursing_table_plan_id meursing_heading_number]

  delegate :description, :formatted_description, to: :footnote_description

  dataset_module do
    def with_footnote_types_and_ids(footnote_types_and_ids)
      return self if footnote_types_and_ids.none?

      conditions = footnote_types_and_ids.map do |type, id|
        Sequel.expr(footnotes__footnote_type_id: type) & Sequel.expr(footnotes__footnote_id: id)
      end
      combined_conditions = conditions.reduce(:|)

      where(combined_conditions)
    end

    def national
      where(national: true)
    end
  end

  def code
    "#{footnote_type_id}#{footnote_id}"
  end

  alias_method :id, :code
end
