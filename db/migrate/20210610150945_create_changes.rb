Sequel.migration do
  change do
    create_table :changes do
      primary_key :id
      String  :goods_nomenclature_item_id
      Integer :goods_nomenclature_sid
      String  :productline_suffix, size: 255
      Bool    :end_line
      String  :change_type,        size: 255
      Date    :change_date
    end
  end
end
