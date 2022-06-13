# Generates a materialized path for all of the goods nomenclatures under a given chapter
#
# We accumulate updates inside of updated_goods_nomenclatures so we can execute one SQL statement
# for each goods nomenclature that has their path updated without slowing ourselves down with lots of queries.
class MaterializedPathUpdaterService
  def initialize(chapter)
    @chapter = chapter
    @updated_goods_nomenclatures = []
  end

  def call
    # We want to use the TimeMachine so we don't have a bunch of non-current goods nomenclatures or
    # duplicate versions of the goods nomenclature that we are targeting.
    TimeMachine.now do
      previous_goods_nomenclature = chapter
      current_path = []

      accumulate_update_for(previous_goods_nomenclature, current_path)

      goods_nomenclatures.each do |current_goods_nomenclature|
        if reset_path?(current_goods_nomenclature, previous_goods_nomenclature)
          current_path = [chapter.goods_nomenclature_sid]
        elsif add_to_path?(current_goods_nomenclature, previous_goods_nomenclature)
          current_path.push(previous_goods_nomenclature.goods_nomenclature_sid)
        elsif remove_from_path?(current_goods_nomenclature, previous_goods_nomenclature)
          pop_count = previous_goods_nomenclature.number_indents - current_goods_nomenclature.number_indents

          current_path.pop(pop_count)
        end

        accumulate_update_for(current_goods_nomenclature, current_path)

        previous_goods_nomenclature = current_goods_nomenclature
      end

      GoodsNomenclature.db.transaction do
        sql = updated_goods_nomenclatures.join(";\n")

        GoodsNomenclature.db.run(sql)
      end
    end
  end

  private

  attr_reader :updated_goods_nomenclatures, :chapter

  def accumulate_update_for(goods_nomenclature, path)
    updated_goods_nomenclatures << GoodsNomenclature::Operation.where(
      oid: goods_nomenclature.oid,
      goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
    ).update_sql(path: Sequel.pg_array(path, :integer))
  end

  def goods_nomenclatures
    @goods_nomenclatures ||= chapter.goods_nomenclatures_dataset.eager(:goods_nomenclature_indents)
  end

  # When the heading changes (e.g. we were previously looking at another heading branch's last commodity and now
  # our cursor is on a new heading branch) we should reset the path to contain just the chapter.
  def reset_path?(current_goods_nomenclature, previous_goods_nomenclature)
    current_goods_nomenclature.heading? && !previous_goods_nomenclature.chapter?
  end

  # The most common case for adding to a previous_goods_nomenclature to the current_goods_nomenclatures path
  # is when the current_goods_nomenclatures indents are larger than the previous_goods_nomenclatures
  #
  # The only exception to this rule is when a heading comes after the chapter. Headings and chapters have the
  # same number of indents but headings are technically underneath chapters so we want to push the chapter into the
  # headings path.
  def add_to_path?(current_goods_nomenclature, previous_goods_nomenclature)
    current_goods_nomenclature.number_indents > previous_goods_nomenclature.number_indents ||
      previous_goods_nomenclature.chapter? && current_goods_nomenclature.heading?
  end

  # When the current_goods_nomenclature's indents drop this indicates we need to remove one
  # or more members from the current goods nomenclature's path (corresponding to how many indents dropped
  # between the previous_goods_nomenclature and the current goods nomenclature.
  def remove_from_path?(current_goods_nomenclature, previous_goods_nomenclature)
    current_goods_nomenclature.number_indents < previous_goods_nomenclature.number_indents
  end
end
