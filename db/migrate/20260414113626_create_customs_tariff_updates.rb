Sequel.migration do
  up do
    if TradeTariffBackend.uk?
      create_table :customs_tariff_updates do
        String   :version, primary_key: true
        Date     :validity_start_date, null: false
        Date     :validity_end_date
        String   :status, null: false, default: 'awaiting_approval'
        String   :source_url, text: true
        String   :s3_path, text: true
        String   :file_checksum
        Date     :document_created_on
        String   :import_error, text: true
        DateTime :created_at, null: false
        DateTime :updated_at, null: false

        index :file_checksum
      end
    end
  end

  down do
    drop_table :customs_tariff_updates
  end
end
