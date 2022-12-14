FactoryBot.define do
  factory :commodity, parent: :goods_nomenclature, class: 'Commodity' do
    trait :declarable do
      producline_suffix { '80' }
    end

    trait :non_declarable do
      producline_suffix { '10' }
    end

    trait :with_indent do
      after(:create) do |commodity, evaluator|
        create(:goods_nomenclature_indent,
               goods_nomenclature_sid: commodity.goods_nomenclature_sid,
               goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
               validity_start_date: commodity.validity_start_date,
               validity_end_date: commodity.validity_end_date,
               productline_suffix: commodity.producline_suffix,
               number_indents: evaluator.indents)
      end
    end

    trait :with_ancestors do
      with_description
      transient {
        include_search_references { false }
      }
      path { Sequel.pg_array([1, 2], :integer) }
      description { 'Horses, other than lemmings' }
      goods_nomenclature_item_id { '0101210000' }
      goods_nomenclature_sid { 3 }

      after(:create) do |commodity, evaluator|
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

        guide = create(:guide, :aircraft_parts)
        create(:guides_goods_nomenclature, guide:, goods_nomenclature: heading)
      end
    end

    trait :with_chapter do
      after(:create) do |commodity, _evaluator|
        create(:chapter, :with_section, :with_note, goods_nomenclature_item_id: commodity.chapter_id.to_s)
      end
    end

    trait :with_heading do
      after(:create) do |commodity, _evaluator|
        create(:heading, goods_nomenclature_item_id: "#{commodity.goods_nomenclature_item_id.first(4)}000000")
        commodity.reload
      end
    end

    trait :with_children do
      goods_nomenclature_sid { 1 }
      path { Sequel.pg_array([], :integer) }

      after(:create) do |commodity, _evaluator|
        # Prepare some intermediate item ids
        item_id = commodity.goods_nomenclature_item_id.to_i

        # Make the commodity a parent
        commodity.producline_suffix = '80'
        commodity.save
        create(:goods_nomenclature_indent,
               goods_nomenclature_sid: 1,
               goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
               validity_start_date: commodity.validity_start_date,
               validity_end_date: commodity.validity_end_date,
               productline_suffix: commodity.producline_suffix,
               number_indents: 1)

        # Add another intermediate level
        create(:commodity,
               :with_indent,
               goods_nomenclature_item_id: (item_id + 1).to_s,
               goods_nomenclature_sid: 2,
               path: Sequel.pg_array([1], :integer),
               producline_suffix: '10',
               indents: 2)

        # Add two leaf commodities
        create(:commodity,
               :with_indent,
               goods_nomenclature_item_id: (item_id + 1).to_s,
               goods_nomenclature_sid: 3,
               path: Sequel.pg_array([1, 2], :integer),
               indents: 3)
        create(:commodity,
               :with_indent,
               goods_nomenclature_item_id: (item_id + 2).to_s,
               goods_nomenclature_sid: 4,
               path: Sequel.pg_array([1, 2], :integer),
               indents: 3)
        commodity.reload
      end
    end
  end
end
