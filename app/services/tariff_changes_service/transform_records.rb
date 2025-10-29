class TariffChangesService
  class TransformRecords
    include Presenter

    def self.call(operation_date)
      new(operation_date).call
    end

    attr_reader :operation_date

    def initialize(operation_date)
      @operation_date = operation_date.to_date
    end

    def call
      tariff_changes = load_tariff_changes
      return [] if tariff_changes.empty?

      transform_records(tariff_changes)
    end

    private

    def load_tariff_changes
      TariffChange
        .where(operation_date: operation_date)
        .eager(:goods_nomenclature)
        .order(:goods_nomenclature_item_id, :type, :action)
        .all
    end

    def transform_records(tariff_changes)
      tariff_changes.map do |tariff_change|
        measure = Measure.where(measure_sid: tariff_change.object_sid).last if tariff_change.type == 'Measure'

        {
          import_export: import_export(measure),
          geo_area: geo_area(measure&.geographical_area, measure&.excluded_geographical_areas),
          measure_type: measure_type(measure),
          chapter: tariff_change.goods_nomenclature.chapter_short_code,
          commodity_code: tariff_change.goods_nomenclature.goods_nomenclature_item_id,
          commodity_code_description: commodity_description(tariff_change.goods_nomenclature),
          type_of_change: format_change_type(tariff_change),
          change: describe_change(tariff_change, measure),
          date_of_effect: tariff_change.date_of_effect.to_s,
          ott_url: ott_url(tariff_change),
          api_url: api_url(tariff_change),
        }
      end
    end

    def ott_url(tariff_change)
      date = tariff_change.date_of_effect
      "https://www.trade-tariff.service.gov.uk/commodities/#{tariff_change.goods_nomenclature_item_id}?day=#{date.day}&month=#{date.month}&year=#{date.year}"
    end

    def api_url(tariff_change)
      "https://www.trade-tariff.service.gov.uk/uk/api/commodities/#{tariff_change.goods_nomenclature_item_id}"
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

    def describe_change(tariff_change, measure)
      case tariff_change.type
      when 'Commodity'
        describe_commodity_change(tariff_change, tariff_change.goods_nomenclature)
      when 'CommodityDescription'
        describe_commodity_description_change(tariff_change, tariff_change.goods_nomenclature)
      when 'Measure'
        describe_measure_change(tariff_change, measure)
      else
        "#{tariff_change.type} #{tariff_change.action}"
      end
    end

    def describe_commodity_change(tariff_change, commodity)
      if tariff_change.action == 'update'
        get_changes(commodity).first
      else
        commodity.code
      end
    end

    def describe_commodity_description_change(tariff_change, commodity)
      description = GoodsNomenclatureDescription.where(goods_nomenclature_sid: tariff_change.goods_nomenclature_sid, goods_nomenclature_description_period_sid: tariff_change.object_sid).last

      if tariff_change.action == 'update'
        get_changes(description).first
      else
        commodity_description(commodity)
      end
    end

    def describe_measure_change(tariff_change, measure)
      if tariff_change.action == 'update'
        get_changes(measure).first
      else
        measure_type(measure)
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
