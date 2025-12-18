class TariffChangesService
  class TransformRecords
    def self.call(operation_date, goods_nomenclature_sids = nil)
      new(operation_date, goods_nomenclature_sids).call
    end

    attr_reader :operation_date, :goods_nomenclature_sids

    def initialize(operation_date, goods_nomenclature_sids = nil)
      @operation_date = operation_date.to_date
      @goods_nomenclature_sids = goods_nomenclature_sids
    end

    def call
      tariff_changes = load_tariff_changes
      return [] if tariff_changes.empty?

      transform_records(tariff_changes)
    end

    private

    attr_accessor :geo_area_cache, :gn_descriptions_cache

    def load_tariff_changes
      query = TariffChange
        .where(operation_date: operation_date)
        .eager(:goods_nomenclature)
        .eager(goods_nomenclature: :goods_nomenclature_descriptions)
        .order(:goods_nomenclature_item_id, :type, :action)

      if goods_nomenclature_sids.present?
        query = query.where(goods_nomenclature_sid: goods_nomenclature_sids)
      end

      tariff_changes = query.all

      # Eagerly load measures for Measure type records
      measure_sids = tariff_changes.select { |tc| tc.type == 'Measure' }.map(&:object_sid).uniq
      if measure_sids.any?
        measures = Measure.where(measure_sid: measure_sids).eager(:measure_type).all.index_by(&:measure_sid)
        tariff_changes.each do |tc|
          tc.instance_variable_set(:@measure, measures[tc.object_sid]) if tc.type == 'Measure'
        end
      end

      # Batch load geographical areas
      geo_area_ids = tariff_changes.map { |tc| tc.metadata&.dig('measure', 'geographical_area_id') }.compact.uniq
      excluded_geo_ids = tariff_changes.map { |tc| tc.metadata&.dig('measure', 'excluded_geographical_area_ids') }.compact.flatten.uniq
      all_geo_ids = (geo_area_ids + excluded_geo_ids).uniq

      if all_geo_ids.any?
        geo_areas = GeographicalArea.where(geographical_area_id: all_geo_ids).all.index_by(&:geographical_area_id)
        @geo_area_cache = geo_areas
      end

      # Batch load GoodsNomenclatureDescription for commodity description changes
      gn_desc_period_sids = tariff_changes.select { |tc| tc.type == 'CommodityDescription' }.map(&:object_sid).uniq
      if gn_desc_period_sids.any?
        descriptions = GoodsNomenclatureDescription
          .where(goods_nomenclature_description_period_sid: gn_desc_period_sids)
          .all
          .index_by(&:goods_nomenclature_description_period_sid)
        @gn_descriptions_cache = descriptions
      end

      tariff_changes
    end

    def transform_records(tariff_changes)
      tariff_changes.map do |tariff_change|
        presented_change = Presenter.new(tariff_change, @geo_area_cache)
        {
          import_export: presented_change.import_export,
          geo_area: presented_change.geo_area,
          measure_type: presented_change.measure_type,
          additional_code: presented_change.additional_code,
          chapter: tariff_change.goods_nomenclature.chapter_short_code,
          commodity_code: tariff_change.goods_nomenclature.goods_nomenclature_item_id,
          commodity_code_description: presented_change.commodity_description,
          type_of_change: format_change_type(presented_change),
          change: describe_change(presented_change),
          date_of_effect: presented_change.date_of_effect,
          ott_url: presented_change.ott_url,
          api_url: presented_change.api_url,
        }
      end
    end

    def format_change_type(tariff_change)
      case tariff_change.action
      when 'creation'
        "#{tariff_change.type} Added"
      when 'update'
        "#{tariff_change.type} Updated"
      when 'ending'
        "#{tariff_change.type} Ending"
      when 'deletion'
        "#{tariff_change.type} Deleted"
      else
        tariff_change.action.humanize
      end
    end

    def describe_change(tariff_change)
      case tariff_change.type
      when 'Commodity'
        describe_commodity_change(tariff_change)
      when 'CommodityDescription'
        describe_commodity_description_change(tariff_change)
      when 'Measure'
        describe_measure_change(tariff_change)
      else
        "#{tariff_change.type} #{tariff_change.action}"
      end
    end

    def describe_commodity_change(tariff_change)
      if tariff_change.action == 'update'
        get_changes(tariff_change.goods_nomenclature).first
      else
        tariff_change.goods_nomenclature.code
      end
    end

    def describe_commodity_description_change(tariff_change)
      description = @gn_descriptions_cache&.fetch(tariff_change.object_sid)

      if tariff_change.action == 'update' && description
        get_changes(description).first
      else
        commodity_description(tariff_change.goods_nomenclature)
      end
    end

    def describe_measure_change(tariff_change)
      if tariff_change.action == 'update'
        get_changes(tariff_change.measure).first
      else
        tariff_change.measure_type
      end
    end

    def get_changes(record)
      excluded_columns = %i[oid operation operation_date created_at updated_at filename]
      changes = []
      change = nil

      if (previous_record = record.previous_record)
        comparable_columns = record.values.keys - excluded_columns

        comparable_columns.each do |column|
          current_value = record.send(column)
          previous_value = previous_record.try(column)

          next if current_value == previous_value

          column = { validity_start_date: :start_date,
                     validity_end_date: :end_date }[column] || column

          change ||= if column == :start_date
                       current_value.to_date.iso8601
                     elsif column == :end_date
                       if current_value.nil?
                         'Removed'
                       else
                         (current_value.to_date + 1.day)&.iso8601
                       end
                     else
                       current_value
                     end

          changes << column.to_s.humanize.downcase
        end
      end

      [change, changes]
    end
  end
end
