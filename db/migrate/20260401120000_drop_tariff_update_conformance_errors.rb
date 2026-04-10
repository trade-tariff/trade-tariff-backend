class DropTariffUpdateConformanceErrors < ActiveRecord::Migration[7.2]
  def up
    drop_table :tariff_update_conformance_errors
  end

  def down
    create_table :tariff_update_conformance_errors do |t|
      t.string :tariff_update_filename, null: false
      t.text :details
      t.timestamps null: false
    end
  end
end
