Sequel.migration do
  change do
       create_table :myott_changes do
      primary_key :id
      String  :goods_nomenclature_item_id
      Integer :goods_nomenclature_sid
      String  :productline_suffix, size: 255
      Bool    :end_line
      String  :description
      String  :change_type,        size: 255
      Date    :validity_start_date
      Date    :validity_end_date
      Date    :operation_date
      String  :moved_to,          size: 255
    end
  end
end
