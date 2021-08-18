class CertificateTypeDescription < Sequel::Model
  plugin :oplog, primary_key: :certificate_type_code

  set_primary_key [:certificate_type_code]
end
