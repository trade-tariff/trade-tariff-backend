module AdminListingDataset
  GENERATED_CONTENT_STATUSES = %w[
    needs_review
    approved
    stale
    manually_edited
    expired
  ].freeze

  def for_nomenclature_type(type)
    return self unless %w[commodity heading subheading].include?(type)

    where(Sequel.lit("(#{nomenclature_type_sql}) = ?", type))
  end

  def for_status(status)
    return self unless GENERATED_CONTENT_STATUSES.include?(status)

    where(generated_content_table[status.to_sym] => true)
  end

  def for_score_category(category)
    score = score_expression

    case category
    when 'bad'
      where(score < 0.3)
    when 'okay'
      where(score >= 0.3).where(score < 0.5)
    when 'good'
      where(score >= 0.5).where(score < 0.85)
    when 'amazing'
      where(score >= 0.85)
    when 'no_score'
      where(score => nil)
    else
      self
    end
  end

  private

  def generated_content_table
    raise NotImplementedError, "#{self.class} must define #generated_content_table"
  end

  def score_expression
    Sequel.lit(score_sql)
  end

  def nomenclature_type_expression
    Sequel.lit(nomenclature_type_sql)
  end

  def nomenclature_type_sql
    chapter_pattern = GoodsNomenclature.sql_pattern_for(GoodsNomenclature::CHAPTER_SUFFIX)
    heading_pattern = GoodsNomenclature.sql_pattern_for(GoodsNomenclature::HEADING_SUFFIX)

    <<~SQL.squish
      CASE
        WHEN "gn"."goods_nomenclature_item_id" LIKE '#{chapter_pattern}' THEN 'chapter'
        WHEN "gn"."goods_nomenclature_item_id" LIKE '#{heading_pattern}' THEN 'heading'
        WHEN "gn"."producline_suffix" != '#{GoodsNomenclature::NON_GROUPING_PRODUCTLINE_SUFFIX}' OR EXISTS (
          SELECT 1
          FROM goods_nomenclature_tree_nodes parent
          JOIN goods_nomenclature_tree_nodes child
            ON child.depth = parent.depth + 1
            AND child.position > parent.position
            AND child.validity_start_date <= CURRENT_DATE
            AND (child.validity_end_date >= CURRENT_DATE OR child.validity_end_date IS NULL)
            AND child.position < COALESCE(
              (SELECT MIN(siblings.position)
               FROM goods_nomenclature_tree_nodes siblings
               WHERE siblings.depth = parent.depth
                 AND siblings.position > parent.position
                 AND siblings.validity_start_date <= CURRENT_DATE
                 AND (siblings.validity_end_date >= CURRENT_DATE OR siblings.validity_end_date IS NULL)
              ), 1000000000000)
          WHERE parent.goods_nomenclature_sid = "gn"."goods_nomenclature_sid"
            AND parent.validity_start_date <= CURRENT_DATE
            AND (parent.validity_end_date >= CURRENT_DATE OR parent.validity_end_date IS NULL)
        ) THEN 'subheading'
        ELSE 'commodity'
      END
    SQL
  end
end
