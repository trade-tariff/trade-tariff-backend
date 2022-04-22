module Api
  module V2
    module Csv
      class HeadingSerializer
        include CsvSerializer

        columns :goods_nomenclature_item_id,
                :goods_nomenclature_sid,
                :declarable,
                :description,
                :description_plain,
                :formatted_description,
                :producline_suffix

        column :leaf do |heading|
          heading.commodities.any? do |commodity|
            commodity.children.any?
          end
        end

      end
    end
  end
end
