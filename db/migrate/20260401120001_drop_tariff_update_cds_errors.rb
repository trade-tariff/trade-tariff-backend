class DropTariffUpdateCdsErrors < ActiveRecord::Migration[7.2]
  def up
    drop_table :tariff_update_cds_errors
  end

  def down
    create_table :tariff_update_cds_errors do |t|
      t.string :tariff_update_filename, null: false
      t.string :model_name
      t.text :details
      t.timestamps null: false
    end
  end
end
