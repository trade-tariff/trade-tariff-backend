FactoryBot.define do
  factory :section do
    position      { id }
    sequence(:id) { |n| n }
    numeral       { %w[I II III].sample }
    title         { Forgery(:basic).text }
    created_at    { Time.zone.now }
    updated_at    { Time.zone.now }

    trait :with_note do
      after(:create) do |section, _evaluator|
        FactoryBot.create(:section_note, section_id: section.id)
      end
    end

    trait :with_chapter do
      after(:create) do |section, _evaluator|
        chapter = create(:chapter)
        chapter.add_section section
        chapter.save
      end
    end
  end

  factory :section_note do
    section

    content { Forgery(:basic).text }
  end
end
