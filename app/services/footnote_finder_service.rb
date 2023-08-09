# This service executes 5 queries to search for footnotes
#
# The first query searches for matching footnotes based on their description
#
# This query result is used to inform the second and third query which searches
# for footnotes based on their associations to goods nomenclatures and measures
#
# These are grouped and combined by footnote type and id
#
# Finally footnotes are retrieved by their id and type and returned and associated with there active goods nomenclatures
class FootnoteFinderService
  ID_INDEX_RANGE = 0..1
  TYPE_INDEX_RANGE = 2..-1

  def initialize(type, id, description)
    @type = type
    @id = id
    @description = description
  end

  def call
    return [] if description_types_and_ids.empty? && (type.blank? || id.blank?)
    return [] if goods_nomenclature_sids.empty?

    Api::V2::FootnoteSearch::FootnotePresenter.wrap(
      footnotes,
      grouped_goods_nomenclatures,
    )
  end

  private

  attr_reader :type, :id, :description

  def footnotes
    all_ids_and_types = all_matching_goods_nomenclatures.keys.map do |key|
      [key[ID_INDEX_RANGE], key[TYPE_INDEX_RANGE]]
    end

    Footnote
      .actual
      .with_footnote_types_and_ids(all_ids_and_types)
      .eager(:footnote_descriptions)
      .all
  end

  def grouped_goods_nomenclatures_by_goods_nomenclature_association
    GoodsNomenclature
      .actual
      .join_footnotes
      .with_footnote_type_id(type)
      .with_footnote_id(id)
      .with_footnote_types_and_ids(description_types_and_ids)
      .distinct(
        :footnotes__footnote_type_id,
        :footnotes__footnote_id,
        :goods_nomenclatures__goods_nomenclature_item_id,
        :goods_nomenclatures__producline_suffix,
      )
      .order(
        :footnotes__footnote_type_id,
        :footnotes__footnote_id,
        :goods_nomenclatures__goods_nomenclature_item_id,
        :goods_nomenclatures__producline_suffix,
      )
      .select_append(:footnotes__footnote_type_id, :footnotes__footnote_id)
      .all
      .group_by { |goods_nomenclature| "#{goods_nomenclature[:footnote_type_id]}#{goods_nomenclature[:footnote_id]}" }
      .transform_values do |goods_nomenclatures|
        goods_nomenclatures.map { |goods_nomenclature| goods_nomenclature[:goods_nomenclature_sid] }
      end
  end

  def grouped_goods_nomenclatures_by_measure_association
    Measure
      .with_regulation_dates_query
      .actual
      .join_footnotes
      .with_footnote_type_id(type)
      .with_footnote_id(id)
      .with_footnote_types_and_ids(description_types_and_ids)
      .distinct(%i[footnotes__footnote_type_id footnotes__footnote_id measures__goods_nomenclature_sid])
      .select_append(:footnotes__footnote_type_id, :footnotes__footnote_id)
      .all
      .group_by { |measure| "#{measure[:footnote_type_id]}#{measure[:footnote_id]}" }
      .transform_values do |measures|
        measures.map { |measure| measure[:goods_nomenclature_sid] }
      end
  end

  def all_matching_goods_nomenclatures
    @all_matching_goods_nomenclatures ||= grouped_goods_nomenclatures_by_goods_nomenclature_association.merge(
      grouped_goods_nomenclatures_by_measure_association,
    ) do |_key, gn_goods_nomenclature_sids, m_goods_nomenclature_sids|
      gn_goods_nomenclature_sids + m_goods_nomenclature_sids
    end
  end

  def goods_nomenclature_sids
    @goods_nomenclature_sids ||= all_matching_goods_nomenclatures.values.flatten.uniq
  end

  def grouped_goods_nomenclatures
    all_matching_goods_nomenclatures.transform_values do |goods_nomenclature_sids|
      goods_nomenclature_sids.map { |goods_nomenclature_sid|
        indexed_goods_nomenclatures[goods_nomenclature_sid]
      }.compact
    end
  end

  def indexed_goods_nomenclatures
    @indexed_goods_nomenclatures ||= GoodsNomenclature
      .actual
      .non_hidden
      .non_classifieds
      .with_leaf_column
      .where(goods_nomenclatures__goods_nomenclature_sid: goods_nomenclature_sids)
      .eager(:goods_nomenclature_descriptions)
      .all
      .index_by(&:goods_nomenclature_sid)
  end

  def description_types_and_ids
    @description_types_and_ids ||= begin
      return [] if normalised_description.blank?

      FootnoteDescription
        .with_fuzzy_description(normalised_description)
        .select_map(%i[footnote_type_id footnote_id])
        .uniq
    end
  end

  def normalised_description
    @normalised_description ||= SearchDescriptionNormaliserService.new(description).call
  end
end
