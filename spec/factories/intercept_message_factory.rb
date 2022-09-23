FactoryBot.define do
  factory :intercept_message, class: 'Beta::Search::InterceptMessage' do
    term {}
    message {}

    trait :with_section_to_transform do
      message do
        'Based on your search term, we believe you are looking for section XV, section position 14 and section code III depending on the constituent material.'
      end
    end

    trait :with_mixture_of_goods_nomenclature_to_transform do
      message do
        'chapter 1, heading 0101, subheading 012012 and commodity 0702000007.'
      end
    end

    trait :with_chapters_to_transform do
      message do
        'This should point to ChaPter 99 and chapters 32 and chapters 1 but not chapter 19812321 but for chapter 9.'
      end
    end

    trait :with_headings_to_transform do
      message do
        'This should point to hEadIngs 0101 and heading 0102 but not heading 2 or heading 012012 but for heading 0105.'
      end
    end

    trait :with_subheadings_to_transform do
      message do
        'This should point to subheadiNg 010511 and subheadings 01051191 and never change subheading 1231 or subheading 1231312312 but for subheading 010512.'
      end
    end

    trait :with_commodities_to_transform do
      message do
        'This should point to coMmodities 0105110000 and cOmmodity 01051191 and never change commodity 1 or commodity 13112313123123 but for commodity 0101210001.'
      end
    end

    trait :without_message do
      message {}
    end
  end
end
