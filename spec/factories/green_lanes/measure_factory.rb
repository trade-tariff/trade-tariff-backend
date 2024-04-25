FactoryBot.define do
  factory :green_lanes_measure, class: 'GreenLanes::Measure' do
    transient do
      category_assessment { create :category_assessment }
      goods_nomenclature { create :commodity }
    end

    category_assessment_id { category_assessment.id }
    goods_nomenclature_item_id { goods_nomenclature.goods_nomenclature_item_id }
    productline_suffix { goods_nomenclature.producline_suffix }
  end
end
