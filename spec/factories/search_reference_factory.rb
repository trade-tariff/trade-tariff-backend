FactoryBot.define do
  sequence(:sid) { |n| n }

  factory :search_reference do
    title { Forgery(:basic).text }
    referenced { create(:heading) }

    trait :with_chapter do
      referenced { create(:chapter, goods_nomenclature_item_id: '0100000000') }
    end

    trait :with_heading do
      referenced { create(:heading, goods_nomenclature_item_id: '0101000000') }
    end

    trait :with_subheading do
      referenced do
        create(
          :commodity,
          producline_suffix: '10',
          goods_nomenclature_item_id: '0101210000',
        )

        Subheading.find(goods_nomenclature_item_id: '0101210000')
      end
    end

    trait :with_commodity do
      referenced { create(:commodity, goods_nomenclature_item_id: '0101291000') }
    end

    trait :with_current_commodity do
      referenced { create(:commodity, validity_end_date: Time.zone.tomorrow) }
    end

    trait :with_non_current_commodity do
      referenced { create(:commodity, validity_end_date: Time.zone.yesterday) }
    end
  end
end
