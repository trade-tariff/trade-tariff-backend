FactoryBot.define do
  factory :heading, parent: :goods_nomenclature, class: 'Heading' do
    indents { 0 }

    goods_nomenclature_item_id do
      if parent
        "#{parent.goods_nomenclature_item_id.first(2)}01000000"
      else
        "#{generate(:heading_short_code)}000000"
      end
    end

    trait :declarable do
      producline_suffix { '80' }
    end

    trait :non_declarable do
      after(:create) do |heading, _evaluator|
        create(:goods_nomenclature,
               :with_description,
               :with_indent,
               goods_nomenclature_item_id: "#{heading.short_code}#{6.times.map { Random.rand(9) }.join}")
      end
    end

    trait :with_chapter do
      before(:create) do |heading, _evaluator|
        chapter = create(:chapter,
                         :with_section,
                         :with_note,
                         :with_description,
                         :with_guide,
                         goods_nomenclature_item_id: heading.chapter_id)

        heading.path = Sequel.pg_array([chapter.goods_nomenclature_sid])
      end
    end

    trait :heading101 do
      goods_nomenclature_item_id { '0101000000' }
    end
  end
end
