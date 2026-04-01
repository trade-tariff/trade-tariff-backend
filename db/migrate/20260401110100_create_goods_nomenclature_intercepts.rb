Sequel.migration do
  change do
    create_table :goods_nomenclature_intercepts do
      Bignum :goods_nomenclature_sid, null: false, primary_key: true
      String :message, text: true
      TrueClass :excluded, null: false, default: false
      DateTime :created_at, null: false, default: Sequel.lit('CURRENT_TIMESTAMP')
      DateTime :updated_at, null: false, default: Sequel.lit('CURRENT_TIMESTAMP')

      index :excluded
    end
  end
end
