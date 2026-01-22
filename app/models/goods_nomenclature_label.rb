class GoodsNomenclatureLabel < Sequel::Model(Sequel[:goods_nomenclature_labels].qualify(:uk))
  plugin :oplog, primary_key: :goods_nomenclature_sid, materialized: true, oplog_table: Sequel[:goods_nomenclature_labels_oplog].qualify(:uk)
  plugin :time_machine
  plugin :auto_validations, not_null: :presence

  set_primary_key [:goods_nomenclature_sid]

  attr_accessor :goods_nomenclature

  def validate
    super

    validates_presence :goods_nomenclature_sid
    validates_presence :goods_nomenclature_type
    validates_presence :goods_nomenclature_item_id
    validates_presence :producline_suffix
    validates_presence :labels
    validate_uniqueness_of_sid
  end

  dataset_module do
    def by_sid(sid)
      where(goods_nomenclature_sid: sid).actual
    end
  end

  class << self
    def build(goods_nomenclature, item)
      labels = {
        'original_description' => goods_nomenclature.classification_description,
        'description' => item.fetch('description', ''),
        'known_brands' => item.fetch('known_brands', []),
        'colloquial_terms' => item.fetch('colloquial_terms', []),
        'synonyms' => item.fetch('synonyms', []),
      }
      new(goods_nomenclature: goods_nomenclature, labels: labels)
    end

    def goods_nomenclature_label_total_pages
      (goods_nomenclatures_dataset.count / TradeTariffBackend.goods_nomenclature_label_page_size.to_f).ceil
    end

    def goods_nomenclatures_dataset
      TimeMachine.now do
        GoodsNomenclature
          .actual
          .with_leaf_column
          .declarable
          .association_left_join(:goods_nomenclature_label)
          .where(Sequel[:goods_nomenclature_label][:goods_nomenclature_sid] => nil)
      end
    end
  end

  private

  def before_validation
    return super unless goods_nomenclature

    self.goods_nomenclature_sid ||= goods_nomenclature.goods_nomenclature_sid
    self.validity_start_date ||= goods_nomenclature.validity_start_date
    self.validity_end_date ||= goods_nomenclature.validity_end_date
    self.goods_nomenclature_item_id ||= goods_nomenclature.goods_nomenclature_item_id
    self.producline_suffix ||= goods_nomenclature.producline_suffix
    self.goods_nomenclature_type ||= goods_nomenclature.class.name
    self.operation ||= 'C'
    self.operation_date ||= Time.zone.today
    super
  end

  def validate_uniqueness_of_sid
    exists = self.class.by_sid(goods_nomenclature_sid).any?

    if exists
      errors.add(:goods_nomenclature_sid, 'A label for this goods_nomenclature_sid already exists for the specified validity period')
    end
  end
end
