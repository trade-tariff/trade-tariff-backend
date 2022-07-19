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
    validity_start_date { 2.years.ago.beginning_of_day }
    validity_end_date   { nil }
    path { Sequel.pg_array([], :integer) }

    # TODO: Put this in a trait. This forces indents on all nomenclature regardless of
    #       what is passed to the individual factory and adds non-fun surprises for developers.
    after(:build) do |gono, evaluator|
      create(
        :goods_nomenclature_indent,
        goods_nomenclature_sid: gono.goods_nomenclature_sid,
        validity_start_date: gono.validity_start_date,
        validity_end_date: gono.validity_end_date,
        number_indents: evaluator.indents,
        productline_suffix: gono.producline_suffix,
      )
    end

    trait :non_current do
      validity_end_date { 1.day.ago }
    end

    trait :with_ancestors do
      path { Sequel.pg_array([1, 2], :integer) }

      after(:create) do
        create(:goods_nomenclature, goods_nomenclature_sid: 1)
        create(:goods_nomenclature, goods_nomenclature_sid: 2)
      end
    end

    trait :without_ancestors do
      path { Sequel.pg_array([], :integer) }
    end

    trait :with_parent do
      path { Sequel.pg_array([1], :integer) }

      after(:create) { create(:goods_nomenclature, goods_nomenclature_sid: 1) }
    end

    trait :without_parent do
      path { Sequel.pg_array([1], :integer) }
    end

    trait :with_siblings do
      path { Sequel.pg_array([1, 2], :integer) }

      after(:create) { create(:goods_nomenclature, path: Sequel.pg_array([1, 2], :integer)) }
    end

    trait :without_siblings do
      path { Sequel.pg_array([1, 2], :integer) }
    end

    trait :with_children do
      goods_nomenclature_sid { 1 }
      path { Sequel.pg_array([], :integer) }

      after(:create) do
        create(
          :goods_nomenclature,
          goods_nomenclature_sid: 2,
          path: Sequel.pg_array([1], :integer),
        )
        create(
          :goods_nomenclature,
          goods_nomenclature_sid: 3,
          path: Sequel.pg_array([1, 2], :integer),
        )
      end
    end

    trait :without_children do
      goods_nomenclature_sid { 1 }
      path { Sequel.pg_array([], :integer) }
    end

    trait :with_descendants do
      with_children
    end

    trait :without_descendants do
      without_children
    end

    trait :chapter do
      goods_nomenclature_item_id { '0100000000' }
    end

    trait :heading do
      goods_nomenclature_item_id { '0101000000' }
    end

    trait :commodity do
      goods_nomenclature_item_id { '0102901019' }
    end

    trait :grouping do
      producline_suffix { '10' }
    end

    trait :non_grouping do
      producline_suffix { '80' }
    end

    trait :with_indent do
      # TODO: Populate this trait
    end

    trait :with_guide do
      after(:create) do |goods_nomenclature, _evaluator|
        guide = create(:guide, :aircraft_parts)

        create(:guides_goods_nomenclature, guide:, goods_nomenclature:)
      end
    end

    trait :non_declarable do
      after(:create) do |heading, _evaluator|
        create(:goods_nomenclature, :with_description,
               :with_indent,
               goods_nomenclature_item_id: "#{heading.short_code}#{6.times.map { Random.rand(9) }.join}")
      end
    end

    trait :with_measures do
      after(:create) do |goods_nomenclature, _evaluator|
        create(
          :measure,
          :third_country,
          :with_measure_type,
          :with_measure_conditions,
          :with_base_regulation,
          goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
          goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
        )
      end
    end

    trait :with_overview_measures do
      after(:create) do |goods_nomenclature, _evaluator|
        create(:measure, :vat, :with_measure_type, goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid, goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id)
        create(:measure, :third_country, :with_measure_type, goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid, goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id)
        create(:measure, :supplementary, :with_measure_type, goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid, goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id)
      end
    end

    trait :with_meursing_measures do
      after(:create) do |goods_nomenclature, _evaluator|
        root_measure = create(
          :measure,
          :third_country,
          :with_base_regulation,
          goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
          goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
          geographical_area_id: '1011',
        )

        # Ad valorem measure component
        create(
          :measure_component,
          :with_duty_expression,
          measure_sid: root_measure.measure_sid,
          duty_expression_id: '01',
        )
        # Placeholder meursing measure component - agricultural component
        create(
          :measure_component,
          :with_duty_expression,
          measure_sid: root_measure.measure_sid,
          duty_expression_id: '12',
        )

        root_measure.reload

        meursing_agricultural_measure = create(:measure, :agricultural, geographical_area_id: '1011')

        create(
          :measure_component,
          duty_amount: 0.0,
          monetary_unit_code: 'EUR',
          measurement_unit_code: 'DTN',
          measure_sid: meursing_agricultural_measure.measure_sid,
        )
      end
    end

    trait :actual do
      validity_start_date { 3.years.ago.beginning_of_day }
      validity_end_date   { nil }
    end

    trait :declarable do
      producline_suffix { '80' }
    end

    trait :expired do
      validity_start_date { 3.years.ago.beginning_of_day }
      validity_end_date   { 1.year.ago.beginning_of_day  }
    end

    trait :with_description do
      before(:create) do |gono, evaluator|
        create(:goods_nomenclature_description, goods_nomenclature_sid: gono.goods_nomenclature_sid,
                                                goods_nomenclature_item_id: gono.goods_nomenclature_item_id,
                                                validity_start_date: gono.validity_start_date,
                                                validity_end_date: gono.validity_end_date,
                                                description: evaluator.description)
      end
    end

    trait :stop_words_description do
      description { 'Live animals with some stop words' }
    end

    trait :negated_description do
      description { 'Live animals, other than cheese' }
    end

    trait :special_chars_description do
      description { "Live#~#? (animals,) $* £' '" }
    end

    trait :xml do
      validity_end_date           { 1.year.ago.beginning_of_day }
      statistical_indicator       { 1 }
    end
  end

  trait :without_children do
    # This is just a labelling trait
  end

  factory :goods_nomenclature_indent do
    goods_nomenclature_sid { generate(:sid) }
    goods_nomenclature_indent_sid { generate(:sid) }
    number_indents { Forgery(:basic).number }
    validity_start_date { 3.years.ago.beginning_of_day }
    validity_end_date   { nil }

    trait :xml do
      goods_nomenclature_item_id     { Forgery(:basic).text(exactly: 2) }
      productline_suffix             { Forgery(:basic).text(exactly: 2) }
      validity_end_date              { 1.year.ago.beginning_of_day }
    end
  end

  factory :goods_nomenclature_description_period do
    goods_nomenclature_sid { generate(:sid) }
    goods_nomenclature_description_period_sid { generate(:sid) }
    validity_start_date { 3.years.ago.beginning_of_day }
    validity_end_date   { nil }

    trait :xml do
      goods_nomenclature_item_id                 { Forgery(:basic).text(exactly: 2) }
      productline_suffix                         { Forgery(:basic).text(exactly: 2) }
      validity_end_date                          { 1.year.ago.beginning_of_day }
    end
  end

  factory :goods_nomenclature_description do
    transient do
      validity_start_date { 3.years.ago.beginning_of_day }
      validity_end_date { nil }
    end

    goods_nomenclature_sid { generate(:sid) }
    description { Forgery(:basic).text }
    goods_nomenclature_description_period_sid { generate(:sid) }

    before(:create) do |gono_description, evaluator|
      create(:goods_nomenclature_description_period, goods_nomenclature_description_period_sid: gono_description.goods_nomenclature_description_period_sid,
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
    validity_start_date                  { 3.years.ago.beginning_of_day }
    validity_end_date                    { nil }
    goods_nomenclature_group_type        { generate(:goods_nomenclature_group_type) }
    goods_nomenclature_group_id          { Forgery(:basic).text(exactly: 2) }
    nomenclature_group_facility_code     { 0 }

    trait :xml do
      validity_end_date { 1.year.ago.beginning_of_day }
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
    validity_start_date            { 3.years.ago.beginning_of_day }
    validity_end_date              { nil }

    trait :xml do
      validity_end_date            { 1.year.ago.beginning_of_day }
    end
  end
end
