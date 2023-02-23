FactoryBot.define do
  factory :commodity, parent: :goods_nomenclature, class: 'Commodity' do
    trait :declarable do
      non_grouping
    end

    trait :non_declarable do
      grouping
    end

    trait :with_ancestors do
      with_description

      transient do
        include_search_references { false }
      end

      description { 'Horses, other than lemmings' }

      before(:create) do |commodity, evaluator|
        chapter = create(
          :chapter,
          :with_description,
          description: 'Live horses, asses, mules and hinnies',
          goods_nomenclature_sid: 1,
          goods_nomenclature_item_id: "#{commodity.goods_nomenclature_item_id.first(2)}00000000",
          validity_start_date: '2020-10-21',
        )

        if evaluator.include_search_references
          create(
            :search_reference,
            referenced: chapter,
            title: 'chapter search reference',
          )
        end

        heading = create(
          :heading,
          :with_description,
          description: 'Live animals',
          goods_nomenclature_sid: 2,
          goods_nomenclature_item_id: "#{commodity.goods_nomenclature_item_id.first(4)}000000",
          validity_start_date: '2020-10-21',
        )

        if evaluator.include_search_references
          create(
            :search_reference,
            referenced: heading,
            title: 'heading search reference',
          )
        end

        # populate materialized path copy of hierarchy
        ancestor_sids = [chapter, heading].map(&:goods_nomenclature_sid)
        commodity.path = Sequel.pg_array(ancestor_sids, :integer)

        guide = create(:guide, :aircraft_parts)
        create(:guides_goods_nomenclature, guide:, goods_nomenclature: heading)
      end
    end

    trait :with_chapter do
      before(:create) do |commodity, _evaluator|
        chapter = create(:chapter, :with_section, :with_note, goods_nomenclature_item_id: commodity.chapter_id.to_s)

        commodity.path = Sequel.pg_array([chapter.goods_nomenclature_sid])
      end
    end

    trait :with_chapter_and_heading do
      before(:create) do |commodity, _evaluator|
        chapter = create(:chapter, :with_section, :with_note, goods_nomenclature_item_id: commodity.chapter_id.to_s)
        heading = create(:heading,
                         goods_nomenclature_item_id: "#{commodity.goods_nomenclature_item_id.first(4)}000000",
                         parent: chapter)

        commodity.path = Sequel.pg_array(heading.path + [heading.goods_nomenclature_sid])
      end
    end

    trait :with_heading do
      before(:create) do |commodity, _evaluator|
        heading = create(:heading, goods_nomenclature_item_id: "#{commodity.goods_nomenclature_item_id.first(4)}000000")

        commodity.path = Sequel.pg_array([heading.goods_nomenclature_sid])
      end
    end

    trait :with_children do
      non_grouping
      indents { 1 }

      after(:create) do |commodity, _evaluator|
        # Add another intermediate level
        subheading = create(:commodity,
                            :with_indent,
                            :grouping,
                            parent: commodity,
                            indents: 2)

        # Add two leaf commodities
        create(:commodity, :with_indent, parent: subheading, indents: 3)
        create(:commodity, :with_indent, parent: subheading, indents: 3)
      end
    end
  end
end
