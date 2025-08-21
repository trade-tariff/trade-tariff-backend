# frozen_string_literal: true

Sequel.migration do
  up do
    drop_table :tradeset_descriptions
  end

  down do
    # Tradesets descriptions come from a CSV file that is produced monthly by the trader.
    # These indicate the description of the classified goods at the time of the classification.
    create_table(:tradeset_descriptions) do
      String :filename, null: false # The filename of the CSV file that this record was extracted from
      Date :classification_date, null: false # Extracted from the filename - the date the goods were classified and described by the trader.
      String :description, null: false # The description of the goods at the time of classification
      String :goods_nomenclature_item_id, null: false # Identifies the goods nomenclature that will be eager loaded
      DateTime :created_at, null: false
      DateTime :updated_at, null: false
      DateTime :validity_start_date, null: false
      DateTime :validity_end_date

      unique %i[filename description goods_nomenclature_item_id]
    end

    alter_table(:tradeset_descriptions) do
      add_index :goods_nomenclature_item_id # Used for an association eager load so we definitely want this
    end
  end
end
