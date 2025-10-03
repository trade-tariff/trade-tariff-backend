class CdsImporter
  class ExcelWriter
    class GoodsNomenclature < BaseMapper
      def sheet_name
        'Commodities'
      end

      def table_span
        %w[A H]
      end

      def column_widths
        [30, 20, 20, 50, 20, 20, 20, 20]
      end

      def heading
        ['Action',
         'Commodity code',
         'Product line suffix',
         'Description',
         'Start date',
         'End date',
         'Statistical indicator',
         'SID']
      end

      def data_row
        grouped = models.group_by { |model| model.class.name }
        gn = grouped['GoodsNomenclature'].first
        footnote_description_periods = grouped['GoodsNomenclatureDescriptionPeriod']
        footnote_descriptions = grouped['GoodsNomenclatureDescription']

        ["#{expand_operation(gn)} commodity",
         gn.goods_nomenclature_item_id,
         gn.producline_suffix,
         periodic_description(footnote_description_periods, footnote_descriptions, &method(:period_matches?)),
         format_date(gn.validity_start_date),
         format_date(gn.validity_end_date),
         gn.statistical_indicator,
         gn.goods_nomenclature_sid
         ]
      end

      private

      def period_matches?(period, description)
        period.goods_nomenclature_description_period_sid == description.goods_nomenclature_description_period_sid &&
          period.goods_nomenclature_sid == description.goods_nomenclature_sid &&
          period.productline_suffix == description.productline_suffix &&
          period.goods_nomenclature_item_id == description.goods_nomenclature_item_id
      end
    end
  end
end
