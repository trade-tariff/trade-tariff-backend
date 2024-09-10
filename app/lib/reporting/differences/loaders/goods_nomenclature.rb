module Reporting
  class Differences
    class Loaders
      class GoodsNomenclature
        include Reporting::Differences::Loaders::Helpers

        def initialize(source, target, report)
          @source = source
          @report = report
          @target = target
        end

        attr_reader :source, :target, :report

        def key
          [self.class.name, source, target].join('_')
        end

        private

        def data
          all_missing = source_goods_nomenclatures.keys - target_goods_nomenclatures.keys
          all_missing.map do |missing|
            build_data_for(missing)
          end
        end

        def build_data_for(missing)
          missing_goods_nomenclature = source_goods_nomenclatures[missing]
          PresentedGoodsNomenclature.new(missing_goods_nomenclature).to_row
        end

        def target_goods_nomenclatures
          @target_goods_nomenclatures ||= read_target.index_by do |goods_nomenclature|
            goods_nomenclature['ItemIDPlusPLS']
          end
        end

        def source_goods_nomenclatures
          @source_goods_nomenclatures ||= read_source.index_by do |goods_nomenclature|
            goods_nomenclature['ItemIDPlusPLS']
          end
        end

        def read_source
          public_send("#{source}_goods_nomenclatures")
        end

        def read_target
          public_send("#{target}_goods_nomenclatures")
        end

        def handle_csv(csv)
          CSV.parse(csv, headers: true).map(&:to_h)
        end
      end

      class PresentedGoodsNomenclature
        def initialize(goods_nomenclature)
          @goods_nomenclature = goods_nomenclature
        end

        def to_row
          [
            sid,
            commodity_code,
            product_line_suffix,
            start_date,
            end_date,
            indentation,
            end_line,
            description,
          ]
        end

        private

        attr_reader :goods_nomenclature

        def sid
          goods_nomenclature['SID']
        end

        def commodity_code
          goods_nomenclature['Commodity code']
        end

        def product_line_suffix
          goods_nomenclature['Product line suffix']
        end

        def start_date
          goods_nomenclature['Start date']&.to_date&.strftime('%d/%m/%Y')
        end

        def end_date
          goods_nomenclature['End date']&.to_date&.strftime('%d/%m/%Y')
        end

        def indentation
          goods_nomenclature['Indentation']
        end

        def end_line
          goods_nomenclature['End line'] == 'true' ? '1' : '0'
        end

        def description
          goods_nomenclature['Description']
        end
      end
    end
  end
end
