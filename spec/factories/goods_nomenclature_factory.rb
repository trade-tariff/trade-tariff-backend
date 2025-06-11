FactoryBot.define do
  sequence(:goods_nomenclature_sid, 100) # Some factories hard code SIDs, so avoid clashing
  sequence(:chapter_short_code, 10) { |n| sprintf '%02d', n }
  sequence(:heading_short_code, 10) { |n| sprintf '01%02d', n }
  sequence(:commodity_short_code) { |n| sprintf '%06d', n }

  factory :goods_nomenclature do
    transient do
      description { Forgery(:basic).text }
      parent { nil }
      indents { parent&.number_indents.to_i + 1 }
    end

    goods_nomenclature_sid { generate(:goods_nomenclature_sid) }
    producline_suffix   { '80' }
    validity_start_date { 2.years.ago.beginning_of_day }
    validity_end_date   { nil }

    goods_nomenclature_item_id do
      heading_code = parent ? parent.goods_nomenclature_item_id.first(4) : '0101'
      [heading_code, generate(:commodity_short_code)].join
    end

    # TODO: Put this in a trait. This forces indents on all nomenclature regardless of
    #       what is passed to the individual factory and adds non-fun surprises for developers.
    after(:build) do |gono, evaluator|
      if evaluator.indents.present?
        gono.associations[:goods_nomenclature_indents] = \
          build_list(
            :goods_nomenclature_indent,
            1,
            goods_nomenclature: gono,
            number_indents: evaluator.indents,
          )
      end
    end

    after(:create) do |gono, _evaluator|
      if gono.associations[:goods_nomenclature_indents]
        gono.associations[:goods_nomenclature_indents].all?(&:save)
        # We clear associations that rely on nested set that might have been
        # loaded before the nested set tree node view was refreshed
        gono.associations.clear

        ViewService.refresh_materialized_views!
      end
    end

    trait :with_deriving_goods_nomenclatures do
      after(:create) do |origin_goods_nomenclature|
        successor_goods_nomenclature = create(:commodity, parent: create(:heading))

        create(
          :goods_nomenclature_origin,
          goods_nomenclature_sid: successor_goods_nomenclature.goods_nomenclature_sid,
          productline_suffix: successor_goods_nomenclature.producline_suffix,
          derived_goods_nomenclature_item_id: origin_goods_nomenclature.goods_nomenclature_item_id,
          derived_productline_suffix: origin_goods_nomenclature.producline_suffix,
        )
      end
    end

    trait :non_current do
      validity_end_date { 1.day.ago }
    end

    trait :with_ancestors do
      parent do
        first = create(:goods_nomenclature,
                       :chapter,
                       goods_nomenclature_item_id: '0200000000')

        create(:goods_nomenclature,
               :heading,
               parent: first,
               goods_nomenclature_item_id: '0201000000')
      end
    end

    trait :without_ancestors do
      parent { nil }
    end

    trait :with_parent do
      parent { create(:goods_nomenclature) }
    end

    trait :without_parent do
      parent { nil }
    end

    trait :with_siblings do
      with_ancestors

      after(:create) do |_gn, evaluator|
        create(:goods_nomenclature, parent: evaluator.parent)
      end
    end

    trait :without_siblings do
      with_ancestors
    end

    trait :with_children do
      after(:create) do |parent|
        child = create(:goods_nomenclature, parent:)
        create(:goods_nomenclature, parent: child)
      end
    end

    trait :without_children do
      # default behaviour
    end

    trait :with_descendants do
      with_children
    end

    trait :without_descendants do
      without_children
    end

    trait :chapter do
      goods_nomenclature_item_id { sprintf '%s00000000', generate(:chapter_short_code) }
      indents { 0 }
    end

    trait :heading do
      goods_nomenclature_item_id { sprintf '%s000000', generate(:heading_short_code) }
      indents { 0 }
    end

    trait :commodity do
      # default behaviour
    end

    trait :grouping do
      producline_suffix { '10' }
    end

    trait :non_grouping do
      producline_suffix { '80' }
    end

    trait :with_indent do
      # Implicit behaviour, always creates indents
      # use indents transient value to control indent depth
    end

    trait :without_indent do
      indents { nil }
    end

    trait :non_declarable do
      after(:create) do |heading, _evaluator|
        create(:goods_nomenclature, :with_description,
               :with_indent,
               goods_nomenclature_item_id: "#{heading.short_code}#{Array.new(6) { Random.rand(9) }.join}")
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

    trait :with_quota_measures do
      after(:create) do |goods_nomenclature, _evaluator|
        create(
          :measure,
          :third_country,
          :with_measure_type,
          :with_measure_conditions,
          :with_base_regulation,
          :preferential_quota,
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
      non_grouping
    end

    trait :expired do
      validity_start_date { 3.years.ago.beginning_of_day }
      validity_end_date   { 1.year.ago.beginning_of_day  }
    end

    trait :with_heading do
      # NOOP: Only subheadings and commodities have headings
    end

    trait :with_description do
      before(:create) do |goods_nomenclature, evaluator|
        create(:goods_nomenclature_description, goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
                                                goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
                                                validity_start_date: goods_nomenclature.validity_start_date,
                                                validity_end_date: goods_nomenclature.validity_end_date,
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

    trait :word_phrase do
      description { '2 LiTres Or Less' }
    end

    trait :xml do
      validity_end_date           { 1.year.ago.beginning_of_day }
      statistical_indicator       { 1 }
    end
  end

  factory :goods_nomenclature_indent do
    transient do
      goods_nomenclature { nil }
    end

    goods_nomenclature_indent_sid { generate(:sid) }
    goods_nomenclature_sid { goods_nomenclature&.goods_nomenclature_sid || generate(:sid) }
    productline_suffix { goods_nomenclature&.producline_suffix || '80' }
    number_indents { Forgery(:basic).number }

    goods_nomenclature_item_id do
      goods_nomenclature&.goods_nomenclature_item_id || "0101#{generate(:commodity_short_code)}"
    end

    validity_start_date { goods_nomenclature&.validity_start_date || 3.years.ago.beginning_of_day }
    validity_end_date   { nil }

    trait :xml do
      goods_nomenclature_item_id     { Forgery(:basic).text(exactly: 2) }
      productline_suffix             { Forgery(:basic).text(exactly: 2) }
      validity_end_date              { 1.year.ago.beginning_of_day }
    end

    after(:create) { GoodsNomenclatures::TreeNode.refresh! }
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

  trait :with_search_reference do
    transient { title { 'foo' } }

    after(:create) do |goods_nomenclature, evaluator|
      create(
        :search_reference,
        referenced: goods_nomenclature,
        title: evaluator.title,
      )
    end
  end

  trait :with_footnote_association do
    after(:build) do |goods_nomenclature, _evaluator|
      create(
        :footnote,
        :with_goods_nomenclature_association,
        goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid,
      )
    end
  end

  trait :hidden do
    after(:create) do |goods_nomenclature, _evaluator|
      create(
        :hidden_goods_nomenclature,
        goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id,
      )
    end
  end

  trait :classified do
    goods_nomenclature_item_id { '9800121221' }
  end

  trait :with_full_chemicals do
    after(:create) do |goods_nomenclature, _evaluator|
      create(:full_chemical, goods_nomenclature:)
    end
  end
end
