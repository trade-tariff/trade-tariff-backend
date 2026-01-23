FactoryBot.define do
  factory :news_collection, class: 'News::Collection' do
    sequence(:name) { |n| "News Collection #{n}" }
    sequence(:slug) { |n| "news_collection_#{n}" }
    published { true }
    subscribable { false }

    trait :with_description do
      sequence(:description) { |n| "Description of News collection #{n}" }
    end

    trait :unpublished do
      published { false }
    end

    trait :subscribable do
      subscribable { true }
    end
  end

  factory :news_item, class: 'News::Item' do
    transient do
      collection_count { 1 }
      collection_traits { nil }
    end

    start_date { 1.day.ago }
    sequence(:title) { |n| "News item #{n}" }
    precis { 'This is the precis' }
    display_style { News::Item::DISPLAY_REGULAR }
    show_on_xi { true }
    show_on_uk { true }
    show_on_updates_page { false }
    show_on_home_page { false }
    show_on_banner { false }

    collection_ids do
      create_list(:news_collection, collection_count, *Array.wrap(collection_traits)).map(&:id)
    end

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

    trait :home_page do
      show_on_home_page { true }
    end

    trait :updates_page do
      show_on_updates_page { true }
    end

    trait :banner do
      show_on_banner { true }
    end

    trait :with_subscribable_collection do
      collection_traits { :subscribable }
    end

    trait :with_non_subscribable_collection do
      collection_traits { nil } # default subscribable is false
    end
  end
end
