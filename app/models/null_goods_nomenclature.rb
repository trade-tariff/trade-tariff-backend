class NullGoodsNomenclature < NullObject
  attr_reader :description_html,
              :description_indexed,
              :description_plain,
              :formatted_description,
              :csv_formatted_description,
              :consigned_from,
              :short_code

  def description
    ''
  end
end
