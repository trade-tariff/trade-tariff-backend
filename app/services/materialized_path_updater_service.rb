# Generates a materialized path for all of the goods nomenclatures under a given chapter
#
# We accumulate updates inside of updated_goods_nomenclatures so we can execute one SQL statement for each goods nomenclature that has their path updated without slowing ourselves down with lots of queries.
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
        # When the heading changes, we restart the accumulation of the current path to be under the chapter
        if current_goods_nomenclature.heading? && previous_goods_nomenclature.not_chapter?
          current_path = [chapter.goods_nomenclature_sid]
        # Chapters and headings have the same indentation and chapters need to live under headings
        elsif current_goods_nomenclature.number_indents > previous_goods_nomenclature.number_indents || previous_goods_nomenclature.chapter? && current_goods_nomenclature.heading?
          current_path.push(previous_goods_nomenclature.goods_nomenclature_sid)
        # We reflect the change in indentation in the path by popping off the path parts that are no longer relevant when the indents drop
        elsif current_goods_nomenclature.number_indents < previous_goods_nomenclature.number_indents
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
end
