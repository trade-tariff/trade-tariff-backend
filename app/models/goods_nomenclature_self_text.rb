class GoodsNomenclatureSelfText < Sequel::Model
  plugin :timestamps, update_on_create: true
  plugin :auto_validations, not_null: :presence

  set_primary_key [:goods_nomenclature_sid]
  unrestrict_primary_key # PK is a natural key (FK to goods_nomenclatures), not auto-increment

  GENERATION_TYPES = %w[mechanical ai].freeze

  many_to_one :goods_nomenclature, key: :goods_nomenclature_sid,
                                   primary_key: :goods_nomenclature_sid

  dataset_module do
    def stale
      where(stale: true)
    end

    def needs_review
      where(needs_review: true)
    end
  end

  def validate
    super
    validates_includes GENERATION_TYPES, :generation_type
  end

  def self.lookup(sid)
    self[sid]&.self_text
  end

  def mark_stale!
    update(stale: true)
  end

  def context_stale?(current_hash)
    context_hash != current_hash
  end
end
