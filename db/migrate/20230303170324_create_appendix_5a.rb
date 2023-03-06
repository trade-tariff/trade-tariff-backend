Sequel.migration do
  up do
    create_table :appendix_5as do
      String :certificate_type_code
      String :certificate_code
      String :chief_guidance
      String :cds_guidance
      DateTime :created_at
      DateTime :updated_at
      primary_key %i[certificate_type_code certificate_code]
    end
  end

  down do
    drop_table :appendix_5as
  end
end
