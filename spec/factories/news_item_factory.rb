FactoryBot.define do
  factory :news_item do
    start_date { 1.day.ago }
    sequence(:title) { |n| "News item #{n}" }
    display_style { NewsItem::DISPLAY_REGULAR }
    show_on_xi { true }
    show_on_uk { true }
    show_on_updates_page { false }
    show_on_home_page { true }

    content do
      <<~CONTENT
        This is some **body** content

        1. With
        2. A list
        3. In it
      CONTENT
    end

    trait :uk_only do
      show_on_xi { false }
    end

    trait :xi_only do
      show_on_uk { false }
    end

    trait :homepage do
      show_on_updates_page { false }
      show_on_home_page { true }
    end

    trait :updates_and_homepage do
      show_on_home_page { true }
    end
  end
end
