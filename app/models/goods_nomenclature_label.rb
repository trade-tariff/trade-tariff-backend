class GoodsNomenclatureLabel < Sequel::Model
  plugin :timestamps, update_on_create: true
  plugin :auto_validations, not_null: :presence
  plugin :has_paper_trail

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

      TimeMachine.now do
        join(:goods_nomenclatures, { Sequel[:gn][:goods_nomenclature_sid] => lbl[:goods_nomenclature_sid] }, table_alias: :gn)
          .where(GoodsNomenclature.validity_dates_filter(:gn))
          .select_all(:goods_nomenclature_labels)
          .select_append(
            nomenclature_type_expression.as(:nomenclature_type),
            score_expression.as(:score),
          )
      end
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
      lbl = '"goods_nomenclature_labels"'

      <<~SQL.squish
        CASE WHEN #{lbl}."description_score" IS NULL
                  AND (#{lbl}."synonym_scores" IS NULL OR array_length(#{lbl}."synonym_scores", 1) IS NULL)
                  AND (#{lbl}."colloquial_term_scores" IS NULL OR array_length(#{lbl}."colloquial_term_scores", 1) IS NULL)
          THEN NULL
          ELSE (
            COALESCE(#{lbl}."description_score", 0) +
            COALESCE((SELECT AVG(s) FROM UNNEST(#{lbl}."synonym_scores") s), 0) +
            COALESCE((SELECT AVG(s) FROM UNNEST(#{lbl}."colloquial_term_scores") s), 0)
          ) / (
            CASE WHEN #{lbl}."description_score" IS NOT NULL THEN 1 ELSE 0 END +
            CASE WHEN #{lbl}."synonym_scores" IS NOT NULL AND array_length(#{lbl}."synonym_scores", 1) > 0 THEN 1 ELSE 0 END +
            CASE WHEN #{lbl}."colloquial_term_scores" IS NOT NULL AND array_length(#{lbl}."colloquial_term_scores", 1) > 0 THEN 1 ELSE 0 END
          )
        END
      SQL
    end
  end

  def score
    self[:score] || computed_score
  end

  def computed_score
    components = []
    components << description_score if description_score
    syn = Array(synonym_scores).compact
    components << (syn.sum / syn.size) if syn.any?
    col = Array(colloquial_term_scores).compact
    components << (col.sum / col.size) if col.any?
    components.any? ? (components.sum / components.size).round(4) : nil
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
        declarable_nomenclatures
          .where(unlabeled | stale_label | self_text_context_changed)
      end
    end

    private

    def declarable_nomenclatures
      gn = Sequel[:goods_nomenclatures]
      st = Sequel[:goods_nomenclature_self_texts]

      GoodsNomenclature
        .actual
        .with_leaf_column
        .declarable
        .association_left_join(:goods_nomenclature_label)
        .left_join(:goods_nomenclature_self_texts, { st[:goods_nomenclature_sid] => gn[:goods_nomenclature_sid] })
    end

    def unlabeled
      Sequel[:goods_nomenclature_label][:goods_nomenclature_sid] =~ nil
    end

    def stale_label
      lbl = Sequel[:goods_nomenclature_label]

      Sequel.&(
        { lbl[:stale] => true },
        { lbl[:manually_edited] => false },
      )
    end

    def self_text_context_changed
      lbl = Sequel[:goods_nomenclature_label]
      st = Sequel[:goods_nomenclature_self_texts]

      Sequel.&(
        { lbl[:manually_edited] => false },
        Sequel.~(st[:self_text] => nil),
        Sequel.~(lbl[:context_hash] => self_text_hash(st)),
      )
    end

    def self_text_hash(self_text_alias)
      Sequel.function(
        :encode,
        Sequel.function(:digest, Sequel.cast(self_text_alias[:self_text], String), 'sha256'),
        'hex',
      )
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
