FactoryBot.define do
  factory :chapter, parent: :goods_nomenclature, class: 'Chapter' do
    goods_nomenclature_item_id { "#{generate(:chapter_short_code)}00000000" }

    trait :with_section do
      after(:create) do |chapter, _evaluator|
        section = create(:section)
        chapter.add_section section
        chapter.save
      end
    end

    trait :with_headings do
      after(:create) do |chapter, _evaluator|
        create(:heading, goods_nomenclature_item_id: "#{chapter.short_code}10000000")
      end
    end

    trait :with_note do
      after(:create) do |chapter, _evaluator|
        create(:chapter_note, chapter_id: chapter.to_param)
      end
    end

    trait :with_guide do
      after(:create) do |chapter, _evaluator|
        guide = create(:chapter_guide)
        chapter.add_guide guide
        chapter.save
      end
    end

    trait :chapter01 do
      goods_nomenclature_item_id { '0100000000' }
    end
  end

  factory :chapter_note do
    chapter

    content { Forgery(:basic).text }
  end

  factory :chapter_guide, class: 'Guide' do
    title { Forgery(:basic).text }
    url { Forgery(:basic).text }
  end
end
