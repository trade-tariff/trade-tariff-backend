FactoryBot.define do
  factory :heading, parent: :goods_nomenclature, class: 'Heading' do
    # +1 is needed to avoid creating heading with gono id in form of
    # xx00xxxxxx which is a Chapter
    goods_nomenclature_item_id { "#{4.times.map { Random.rand(1..8) }.join}000000" }

    trait :declarable do
      producline_suffix { '80' }
    end

    trait :non_declarable do
      after(:create) do |heading, _evaluator|
        create(:goods_nomenclature, :with_description,
                          :with_indent,
                          goods_nomenclature_item_id: "#{heading.short_code}#{6.times.map { Random.rand(9) }.join}")
      end
    end

    trait :with_chapter do
      after(:create) do |heading, _evaluator|
        create(:chapter, :with_section,
                          :with_note,
                          :with_description,
                          :with_guide,
                          goods_nomenclature_item_id: heading.chapter_id)
      end
    end
  end
end
