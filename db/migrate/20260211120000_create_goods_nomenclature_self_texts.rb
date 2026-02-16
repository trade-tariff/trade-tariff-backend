Sequel.migration do
  up do
    create_table :goods_nomenclature_self_texts do
      Integer   :goods_nomenclature_sid, primary_key: true
      String    :goods_nomenclature_item_id, size: 10, null: false
      String    :self_text, text: true, null: false
      String    :generation_type, null: false
      column    :input_context, :jsonb, null: false
      String    :context_hash, size: 64, null: false
      TrueClass :needs_review, default: false
      TrueClass :manually_edited, default: false
      TrueClass :stale, default: false
      DateTime  :generated_at, null: false
      DateTime  :created_at, null: false
      DateTime  :updated_at, null: false

      index :goods_nomenclature_item_id
      index :generation_type
    end

    run "CREATE INDEX idx_self_texts_stale ON goods_nomenclature_self_texts (stale) WHERE stale = TRUE"
    run "CREATE INDEX idx_self_texts_needs_review ON goods_nomenclature_self_texts (needs_review) WHERE needs_review = TRUE"
  end

  down do
    drop_table :goods_nomenclature_self_texts
  end
end
