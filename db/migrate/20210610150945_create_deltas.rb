Sequel.migration do
  change do
    create_table :deltas do
      primary_key :id
      String  :goods_nomenclature_item_id
      String  :goods_nomenclature_sid
      String  :productline_suffix, size: 255
      Bool    :end_line
      String  :delta_type,         size: 255
      Date    :delta_date
    end
  end
end
