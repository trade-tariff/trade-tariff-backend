FactoryBot.define do
  sequence(:goods_nomenclature_sid) { |n| n }
  sequence(:goods_nomenclature_group_id, LoopingSequence.lower_a_to_upper_z, &:value)
  sequence(:goods_nomenclature_group_type, LoopingSequence.lower_a_to_upper_z, &:value)

  factory :goods_nomenclature do
    transient do
      indents { 1 }
      description { Forgery(:basic).text }
    end

    goods_nomenclature_sid { generate(:goods_nomenclature_sid) }
    # do not allow zeroes in the goods item id as it causes unpredictable
    # results
    goods_nomenclature_item_id { 10.times.map { Random.rand(1..9) }.join }
    producline_suffix   { '80' }
    validity_start_date { Date.current.ago(2.years) }
    validity_end_date   { nil }

    after(:build) do |gono, evaluator|
      FactoryBot.create(:goods_nomenclature_indent, goods_nomenclature_sid: gono.goods_nomenclature_sid,
                                                    validity_start_date: gono.validity_start_date,
                                                    validity_end_date: gono.validity_end_date,
                                                    number_indents: evaluator.indents)
    end

    trait :actual do
      validity_start_date { Date.current.ago(3.years) }
      validity_end_date   { nil }
    end

    trait :declarable do
      producline_suffix { '80' }
    end

    trait :expired do
      validity_start_date { Date.current.ago(3.years) }
      validity_end_date   { Date.current.ago(1.year)  }
    end

    trait :with_indent do
      # noop
    end

    trait :with_description do
      before(:create) do |gono, evaluator|
        FactoryBot.create(:goods_nomenclature_description, goods_nomenclature_sid: gono.goods_nomenclature_sid,
                                                           goods_nomenclature_item_id: gono.goods_nomenclature_item_id,
                                                           validity_start_date: gono.validity_start_date,
                                                           validity_end_date: gono.validity_end_date,
                                                           description: evaluator.description)
      end
    end

    trait :xml do
      validity_end_date           { Date.current.ago(1.year) }
      statistical_indicator       { 1 }
    end
  end

  factory :commodity, parent: :goods_nomenclature, class: 'Commodity' do
    trait :declarable do
      producline_suffix { '80' }
    end

    trait :non_declarable do
      producline_suffix { '10' }
    end

    trait :with_indent do
      after(:create) do |commodity, evaluator|
        FactoryBot.create(:goods_nomenclature_indent,
                          goods_nomenclature_sid: commodity.goods_nomenclature_sid,
                          goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
                          validity_start_date: commodity.validity_start_date,
                          validity_end_date: commodity.validity_end_date,
                          productline_suffix: commodity.producline_suffix,
                          number_indents: evaluator.indents)
      end
    end

    trait :with_chapter do
      after(:create) do |commodity, _evaluator|
        FactoryBot.create(:chapter, :with_section, :with_note, goods_nomenclature_item_id: commodity.chapter_id.to_s)
      end
    end

    trait :with_heading do
      after(:create) do |commodity, _evaluator|
        FactoryBot.create(:heading, goods_nomenclature_item_id: "#{commodity.goods_nomenclature_item_id.first(4)}000000")
        commodity.reload
      end
    end

    trait :with_children do
      after(:create) do |commodity, _evaluator|
        # Prepare some intermediate item ids
        item_id = commodity.goods_nomenclature_item_id.to_i

        # Make the commodity a parent
        commodity.producline_suffix = '80'
        commodity.save
        FactoryBot.create(:goods_nomenclature_indent,
                          goods_nomenclature_sid: commodity.goods_nomenclature_sid,
                          goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
                          validity_start_date: commodity.validity_start_date,
                          validity_end_date: commodity.validity_end_date,
                          productline_suffix: commodity.producline_suffix,
                          number_indents: 1)

        # Add another intermediate level
        FactoryBot.create(:commodity,
                          :with_indent,
                          goods_nomenclature_item_id: (item_id + 1).to_s,
                          producline_suffix: '10',
                          indents: 2)

        # Add two leaf commodities
        FactoryBot.create(:commodity,
                          :with_indent,
                          goods_nomenclature_item_id: (item_id + 1).to_s,
                          indents: 3)
        FactoryBot.create(:commodity,
                          :with_indent,
                          goods_nomenclature_item_id: (item_id + 2).to_s,
                          indents: 3)
        commodity.reload
      end
    end
  end

  # WIP
  factory :heading, parent: :goods_nomenclature, class: 'Heading' do
    # +1 is needed to avoid creating heading with gono id in form of
    # xx00xxxxxx which is a Chapter
    goods_nomenclature_item_id { "#{4.times.map { Random.rand(1..8) }.join}000000" }

    trait :declarable do
      producline_suffix { '80' }
    end

    trait :non_grouping do
      producline_suffix { '80' }
    end

    trait :non_declarable do
      after(:create) do |heading, _evaluator|
        FactoryBot.create(:goods_nomenclature, :with_description,
                          :with_indent,
                          goods_nomenclature_item_id: "#{heading.short_code}#{6.times.map { Random.rand(9) }.join}")
      end
    end

    trait :with_chapter do
      after(:create) do |heading, _evaluator|
        FactoryBot.create(:chapter, :with_section,
                          :with_note,
                          :with_description,
                          :with_guide,
                          goods_nomenclature_item_id: heading.chapter_id)
      end
    end
  end

  factory :goods_nomenclature_indent do
    goods_nomenclature_sid { generate(:sid) }
    goods_nomenclature_indent_sid { generate(:sid) }
    number_indents { Forgery(:basic).number }
    validity_start_date { Date.current.ago(3.years) }
    validity_end_date   { nil }

    trait :xml do
      goods_nomenclature_item_id     { Forgery(:basic).text(exactly: 2) }
      productline_suffix             { Forgery(:basic).text(exactly: 2) }
      validity_end_date              { Date.current.ago(1.year) }
    end
  end

  factory :goods_nomenclature_description_period do
    goods_nomenclature_sid { generate(:sid) }
    goods_nomenclature_description_period_sid { generate(:sid) }
    validity_start_date { Date.current.ago(3.years) }
    validity_end_date   { nil }

    trait :xml do
      goods_nomenclature_item_id                 { Forgery(:basic).text(exactly: 2) }
      productline_suffix                         { Forgery(:basic).text(exactly: 2) }
      validity_end_date                          { Date.current.ago(1.year) }
    end
  end

  factory :goods_nomenclature_description do
    transient do
      validity_start_date { Date.current.ago(3.years) }
      validity_end_date { nil }
    end

    goods_nomenclature_sid { generate(:sid) }
    description { Forgery(:basic).text }
    goods_nomenclature_description_period_sid { generate(:sid) }

    before(:create) do |gono_description, evaluator|
      FactoryBot.create(:goods_nomenclature_description_period, goods_nomenclature_description_period_sid: gono_description.goods_nomenclature_description_period_sid,
                                                                goods_nomenclature_sid: gono_description.goods_nomenclature_sid,
                                                                goods_nomenclature_item_id: gono_description.goods_nomenclature_item_id,
                                                                validity_start_date: evaluator.validity_start_date,
                                                                validity_end_date: evaluator.validity_end_date)
    end

    trait :xml do
      language_id                                { 'EN' }
      goods_nomenclature_item_id                 { Forgery(:basic).text(exactly: 2) }
      productline_suffix                         { Forgery(:basic).text(exactly: 2) }
    end
  end

  factory :goods_nomenclature_group do
    validity_start_date                  { Date.current.ago(3.years) }
    validity_end_date                    { nil }
    goods_nomenclature_group_type        { generate(:goods_nomenclature_group_type) }
    goods_nomenclature_group_id          { Forgery(:basic).text(exactly: 2) }
    nomenclature_group_facility_code     { 0 }

    trait :xml do
      validity_end_date { Date.current.ago(1.year) }
    end
  end

  factory :goods_nomenclature_group_description do
    goods_nomenclature_group_type  { generate(:goods_nomenclature_group_type) }
    goods_nomenclature_group_id    { generate(:goods_nomenclature_group_id) }
    description                    { Forgery(:lorem_ipsum).sentence }

    trait :xml do
      language_id                  { 'EN' }
    end
  end

  factory :goods_nomenclature_origin do
    goods_nomenclature_sid              { generate(:sid) }
    derived_goods_nomenclature_item_id  { Forgery(:basic).text(exactly: 2) }
    derived_productline_suffix          { Forgery(:basic).text(exactly: 2) }
    goods_nomenclature_item_id          { Forgery(:basic).text(exactly: 2) }
    productline_suffix                  { Forgery(:basic).text(exactly: 2) }
  end

  factory :goods_nomenclature_successor do
    goods_nomenclature_sid               { generate(:sid) }
    absorbed_goods_nomenclature_item_id  { Forgery(:basic).text(exactly: 2) }
    absorbed_productline_suffix          { Forgery(:basic).text(exactly: 2) }
    goods_nomenclature_item_id           { Forgery(:basic).text(exactly: 2) }
    productline_suffix                   { Forgery(:basic).text(exactly: 2) }
  end

  factory :nomenclature_group_membership do
    goods_nomenclature_sid         { generate(:sid) }
    goods_nomenclature_group_type  { generate(:goods_nomenclature_group_type) }
    goods_nomenclature_group_id    { Forgery(:basic).text(exactly: 2) }
    goods_nomenclature_item_id     { Forgery(:basic).text(exactly: 2) }
    productline_suffix             { Forgery(:basic).text(exactly: 2) }
    validity_start_date            { Date.current.ago(3.years) }
    validity_end_date              { nil }

    trait :xml do
      validity_end_date            { Date.current.ago(1.year) }
    end
  end
end
