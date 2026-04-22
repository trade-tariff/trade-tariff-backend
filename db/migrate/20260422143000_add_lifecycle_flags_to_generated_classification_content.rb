Sequel.migration do
  up do
    alter_table :goods_nomenclature_self_texts do
      add_column :approved, TrueClass, null: false, default: false
      add_column :expired, TrueClass, null: false, default: false
    end

    run 'CREATE INDEX idx_self_texts_approved ON goods_nomenclature_self_texts (approved) WHERE approved = TRUE'
    run 'CREATE INDEX idx_self_texts_expired ON goods_nomenclature_self_texts (expired) WHERE expired = TRUE'

    alter_table :goods_nomenclature_labels do
      add_column :needs_review, TrueClass, null: false, default: false
      add_column :approved, TrueClass, null: false, default: false
      add_column :expired, TrueClass, null: false, default: false
    end

    run 'CREATE INDEX idx_labels_needs_review ON goods_nomenclature_labels (needs_review) WHERE needs_review = TRUE'
    run 'CREATE INDEX idx_labels_approved ON goods_nomenclature_labels (approved) WHERE approved = TRUE'
    run 'CREATE INDEX idx_labels_expired ON goods_nomenclature_labels (expired) WHERE expired = TRUE'
  end

  down do
    run 'DROP INDEX IF EXISTS idx_labels_expired'
    run 'DROP INDEX IF EXISTS idx_labels_approved'
    run 'DROP INDEX IF EXISTS idx_labels_needs_review'

    alter_table :goods_nomenclature_labels do
      drop_column :expired
      drop_column :approved
      drop_column :needs_review
    end

    run 'DROP INDEX IF EXISTS idx_self_texts_expired'
    run 'DROP INDEX IF EXISTS idx_self_texts_approved'

    alter_table :goods_nomenclature_self_texts do
      drop_column :expired
      drop_column :approved
    end
  end
end
