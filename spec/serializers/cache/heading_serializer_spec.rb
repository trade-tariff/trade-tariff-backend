RSpec.describe Cache::HeadingSerializer do
  subject(:serialized) { described_class.new(heading.reload).as_json }

  let!(:chapter) do
    create(
      :chapter,
      :with_section,
      :with_description,
      goods_nomenclature_item_id: heading.chapter_id,
    )
  end
  let!(:forum_link) do
    ForumLink.create(
      url: '123',
      goods_nomenclature_sid: chapter.goods_nomenclature_sid,
    )
  end
  let!(:footnote) do
    create(
      :footnote,
      :with_gono_association,
      goods_nomenclature_sid: heading.goods_nomenclature_sid,
    )
  end
  let!(:measure) do
    create(
      :measure,
      :with_measure_type,
      :with_base_regulation,
      :third_country,
      goods_nomenclature: commodity,
      goods_nomenclature_sid: commodity.goods_nomenclature_sid,
    )
  end

  let!(:commodity) { heading.commodities.first }
  let!(:measure_type) { create :measure_type, measure_type_id: '103' }

  context 'when the heading is a Heading' do
    let(:heading) { create(:heading, :non_declarable) }

    let(:pattern) do
      {
        id: Integer,
        goods_nomenclature_sid: Integer,
        goods_nomenclature_item_id: String,
        producline_suffix: String,
        validity_start_date: String,
        validity_end_date: nil,
        description: String,
        formatted_description: String,
        bti_url: String,
        number_indents: Integer,
        chapter: {
          id: Integer,
          goods_nomenclature_sid: Integer,
          goods_nomenclature_item_id: String,
          producline_suffix: String,
          validity_start_date: String,
          validity_end_date: nil,
          description: String,
          formatted_description: String,
          forum_link: {
            url: String,
          },
          chapter_note: nil,
          guide_ids: Array,
          guides: Array,
        },
        section_id: Integer,
        section: {
          id: Integer,
          numeral: String,
          title: String,
          position: Integer,
          section_note: nil,
        },
        footnotes: [
          {
            footnote_id: String,
            validity_start_date: String,
            validity_end_date: nil,
            code: String,
            description: String,
            formatted_description: String,
          },
        ],
        commodities: [
          {
            id: Integer,
            goods_nomenclature_sid: Integer,
            goods_nomenclature_item_id: String,
            validity_start_date: String,
            validity_end_date: nil,
            goods_nomenclature_indents: [
              {
                goods_nomenclature_indent_sid: Integer,
                validity_start_date: String,
                validity_end_date: nil,
                number_indents: Integer,
                productline_suffix: '80',
              },
            ],
            goods_nomenclature_descriptions: [
              {
                goods_nomenclature_description_period_sid: Integer,
                validity_start_date: String,
                validity_end_date: nil,
                description: String,
                formatted_description: String,
                description_plain: String,
              },
            ],
            overview_measures: [
              {
                measure_sid: Integer,
                effective_start_date: String,
                effective_end_date: String,
                goods_nomenclature_sid: Integer,
                vat: false,
                duty_expression_id: String,
                duty_expression: {
                  id: String,
                  base: String,
                  formatted_base: String,
                },
                measure_type_id: String,
                measure_type: {
                  measure_type_id: String,
                  description: String,
                },
              },
            ],
          },
        ],
      }
    end

    it { is_expected.to match_json_expression(pattern) }
  end

  context 'when the heading is a Subheading' do
    let(:heading) do
      create(
        :commodity,
        :with_indent,
        :with_description,
        :with_heading,
        producline_suffix: '10',
        goods_nomenclature_item_id: '0101210000',
      )

      Subheading.find(goods_nomenclature_item_id: '0101210000')
    end

    let(:pattern) do
      {
        id: Integer,
        goods_nomenclature_sid: Integer,
        goods_nomenclature_item_id: String,
        producline_suffix: String,
        validity_start_date: String,
        validity_end_date: nil,
        description: String,
        formatted_description: String,
        bti_url: String,
        number_indents: Integer,
        chapter: {
          id: Integer,
          goods_nomenclature_sid: Integer,
          goods_nomenclature_item_id: String,
          producline_suffix: String,
          validity_start_date: String,
          validity_end_date: nil,
          description: String,
          formatted_description: String,
          forum_link: {
            url: String,
          },
          chapter_note: nil,
          guide_ids: Array,
          guides: Array,
        },
        section_id: Integer,
        section: {
          id: Integer,
          numeral: String,
          title: String,
          position: Integer,
          section_note: nil,
        },
        heading: {
          id: Integer,
          goods_nomenclature_sid: Integer,
          goods_nomenclature_item_id: String,
          description: '',
          formatted_description: '',
          description_plain: '',
        },
        footnotes: Array,
        commodities: Array,
      }
    end

    it { is_expected.to match_json_expression(pattern) }
  end
end
