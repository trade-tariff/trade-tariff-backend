# Idempotent: WHERE clause only matches the old path pattern without the uk/ prefix.
Sequel.migration do
  up do
    run <<~SQL
      UPDATE customs_tariff_updates
      SET s3_path = REPLACE(s3_path,
                            'data/customs_tariff_documents/UKGT_',
                            'data/customs_tariff_documents/uk/UKGT_')
      WHERE s3_path LIKE 'data/customs_tariff_documents/UKGT_%.docx'
    SQL
  end

  down do
    run <<~SQL
      UPDATE customs_tariff_updates
      SET s3_path = REPLACE(s3_path,
                            'data/customs_tariff_documents/uk/UKGT_',
                            'data/customs_tariff_documents/UKGT_')
      WHERE s3_path LIKE 'data/customs_tariff_documents/uk/UKGT_%.docx'
    SQL
  end
end
