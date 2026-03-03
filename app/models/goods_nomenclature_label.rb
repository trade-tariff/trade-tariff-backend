class GoodsNomenclatureLabel < Sequel::Model
  plugin :timestamps, update_on_create: true
  plugin :auto_validations, not_null: :presence

  set_primary_key [:goods_nomenclature_sid]
  unrestrict_primary_key

  attr_accessor :goods_nomenclature

  def validate
    super

    validates_presence :goods_nomenclature_sid
    validates_presence :goods_nomenclature_type
    validates_presence :goods_nomenclature_item_id
    validates_presence :producline_suffix
    validates_presence :labels
  end

  dataset_module do
    include AdminListingDataset

    def by_sid(sid)
      where(goods_nomenclature_sid: sid)
    end

    def stale
      where(stale: true)
    end

    def needing_relabel
      where(stale: true, manually_edited: false)
    end

    def admin_listing
      lbl = Sequel[:goods_nomenclature_labels]
      gn = Sequel[:gn]
      current_date = Sequel.lit('CURRENT_DATE')

      join(:goods_nomenclatures, { gn[:goods_nomenclature_sid] => lbl[:goods_nomenclature_sid] }, table_alias: :gn)
        .where(gn[:validity_start_date] <= current_date)
        .where(Sequel.|({ gn[:validity_end_date] => nil }, gn[:validity_end_date] >= current_date))
        .select_all(:goods_nomenclature_labels)
        .select_append(
          nomenclature_type_expression.as(:nomenclature_type),
          score_expression.as(:score),
        )
    end

    def search(query)
      return self if query.blank?

      q = query.strip
      lbl = Sequel[:goods_nomenclature_labels]

      if q.match?(/\A\d{2,10}\z/)
        where(Sequel.like(lbl[:goods_nomenclature_item_id], "#{q}%"))
      elsif q.length >= 2
        term = "%#{q}%"
        where(
          Sequel.ilike(lbl[:description], term) |
          Sequel.ilike(Sequel.function(:array_to_string, lbl[:synonyms], ' '), term) |
          Sequel.ilike(Sequel.function(:array_to_string, lbl[:colloquial_terms], ' '), term) |
          Sequel.ilike(Sequel.function(:array_to_string, lbl[:known_brands], ' '), term),
        )
      else
        self
      end
    end

    def for_status(status)
      lbl = Sequel[:goods_nomenclature_labels]

      case status
      when 'stale'
        where(lbl[:stale] => true)
      when 'manually_edited'
        where(lbl[:manually_edited] => true)
      else
        self
      end
    end

    private

    def score_sql
      '"goods_nomenclature_labels"."description_score"'
    end
  end

  def mark_stale!
    update(stale: true)
  end

  def context_stale?(hash)
    context_hash != hash
  end

  class << self
    def build(goods_nomenclature, item, contextual_description: nil)
      description_text = contextual_description || goods_nomenclature.classification_description

      labels_hash = {
        'original_description' => description_text,
        'description' => item.fetch('description', ''),
        'known_brands' => item.fetch('known_brands', []),
        'colloquial_terms' => item.fetch('colloquial_terms', []),
        'synonyms' => item.fetch('synonyms', []),
      }

      new(
        goods_nomenclature: goods_nomenclature,
        labels: labels_hash,
        original_description: description_text,
        description: item.fetch('description', ''),
        known_brands: Sequel.pg_array(item.fetch('known_brands', []), :text),
        colloquial_terms: Sequel.pg_array(item.fetch('colloquial_terms', []), :text),
        synonyms: Sequel.pg_array(item.fetch('synonyms', []), :text),
      ).tap do |label|
        label.context_hash = Digest::SHA256.hexdigest(description_text.to_s)
      end
    end

    def goods_nomenclature_label_total_pages
      page_size = AdminConfiguration.integer_value('label_page_size')
      (goods_nomenclatures_dataset.count / page_size.to_f).ceil
    end

    def goods_nomenclatures_dataset
      TimeMachine.now do
        GoodsNomenclature
          .actual
          .with_leaf_column
          .declarable
          .association_left_join(:goods_nomenclature_label)
          .where(
            Sequel.|(
              { Sequel[:goods_nomenclature_label][:goods_nomenclature_sid] => nil },
              Sequel.&(
                { Sequel[:goods_nomenclature_label][:stale] => true },
                { Sequel[:goods_nomenclature_label][:manually_edited] => false },
              ),
            ),
          )
      end
    end
  end

  def before_validation
    return super unless goods_nomenclature

    self.goods_nomenclature_sid ||= goods_nomenclature.goods_nomenclature_sid
    self.goods_nomenclature_item_id ||= goods_nomenclature.goods_nomenclature_item_id
    self.producline_suffix ||= goods_nomenclature.producline_suffix
    self.goods_nomenclature_type ||= goods_nomenclature.class.name
    super
  end
end
