RSpec.describe Api::V2::ChaptersController, 'GET #show' do
  let(:heading) { create :heading, :with_chapter }
  let(:chapter) { heading.reload.chapter }
  let!(:section) { chapter.section }
  let!(:section_note) { create :section_note, section_id: section.id }
  let(:chapter_guide) { chapter.guides.first }
  let!(:chapter_note) { chapter.chapter_note }

  let(:pattern) do
    {
      data: {
        id: chapter.goods_nomenclature_sid.to_s,
        type: 'chapter',
        attributes: {
          goods_nomenclature_sid: chapter.goods_nomenclature_sid,
          goods_nomenclature_item_id: chapter.goods_nomenclature_item_id,
          description: chapter.description,
          formatted_description: chapter.formatted_description,
          chapter_note: chapter_note.content,
          forum_url: chapter.forum_link&.url,
          section_id: section.id,
        },
        relationships: {
          section: {
            data: {
              id: section.id.to_s,
              type: 'section',
            },
          },
          guides: {
            data: [
              {
                id: chapter_guide.id.to_s,
                type: 'guide',
              },
            ],
          },
          headings: {
            data: [
              {
                id: heading.goods_nomenclature_sid.to_s,
                type: 'heading',
              },
            ],
          },
        },
      },
      included: [
        {
          id: chapter.section.id.to_s,
          type: 'section',
          attributes: {
            id: section.id,
            position: section.position,
            title: section.title,
            numeral: section.numeral,
            section_note: section_note.content,
          },
        },
        {
          id: chapter_guide.id.to_s,
          type: 'guide',
          attributes: {
            title: chapter_guide.title,
            url: chapter_guide.url,
          },
        },
        {
          id: heading.goods_nomenclature_sid.to_s,
          type: 'heading',
          attributes: {
            goods_nomenclature_sid: heading.goods_nomenclature_sid,
            goods_nomenclature_item_id: heading.goods_nomenclature_item_id,
            declarable: heading.declarable,
            description: heading.description,
            producline_suffix: heading.producline_suffix,
            leaf: true,
            description_plain: heading.description_plain,
            formatted_description: heading.formatted_description,
          },
          relationships: {
            children: {
              data: Array,
            },
          },
        },
      ],
    }
  end

  context 'when record is present' do
    it 'returns rendered record' do
      get :show, params: { id: chapter }, format: :json

      expect(response.body).to match_json_expression pattern
    end
  end

  context 'when record is not present' do
    it 'returns not found if record was not found' do
      id = chapter.goods_nomenclature_item_id.first(2).to_i + 1
      get :show, params: { id: id }, format: :json

      expect(response.status).to eq 404
    end
  end

  context 'when record is hidden' do
    let!(:hidden_goods_nomenclature) { create :hidden_goods_nomenclature, goods_nomenclature_item_id: chapter.goods_nomenclature_item_id }

    it 'returns not found' do
      get :show, params: { id: chapter.goods_nomenclature_item_id.first(2) }, format: :json

      expect(response.status).to eq 404
    end
  end
end

RSpec.describe Api::V2::ChaptersController, 'GET #index' do
  let!(:chapter1) { create :chapter, :with_section, :with_note }
  let!(:chapter2) { create :chapter, :with_section, :with_note }

  let(:pattern) do
    {
      data: [
        {
          id: chapter1.goods_nomenclature_sid.to_s,
          type: 'chapter',
          attributes: {
            goods_nomenclature_sid: chapter1.goods_nomenclature_sid,
            goods_nomenclature_item_id: chapter1.goods_nomenclature_item_id,
            formatted_description: chapter1.formatted_description,
          },
        },
        {
          id: chapter2.goods_nomenclature_sid.to_s,
          type: 'chapter',
          attributes: {
            goods_nomenclature_sid: chapter2.goods_nomenclature_sid,
            goods_nomenclature_item_id: chapter2.goods_nomenclature_item_id,
            formatted_description: chapter2.formatted_description,
          },
        },
      ],
    }
  end

  it 'returns rendered records' do
    get :index, format: :json

    expect(response.body).to match_json_expression pattern
  end
end

RSpec.describe Api::V2::ChaptersController, 'GET #changes' do
  context 'changes happened after chapter creation' do
    let(:chapter) do
      create :chapter, :with_section, :with_note,
             operation_date: Date.current
    end

    let(:heading) { create :heading, goods_nomenclature_item_id: "#{chapter.goods_nomenclature_item_id.first(2)}20000000" }
    let!(:measure) do
      create :measure,
             :with_measure_type,
             goods_nomenclature: heading,
             goods_nomenclature_sid: heading.goods_nomenclature_sid,
             goods_nomenclature_item_id: heading.goods_nomenclature_item_id,
             operation_date: Date.current
    end

    let(:pattern) do
      {
        data: [
          {
            id: String,
            type: 'change',
            attributes: {
              oid: Integer,
              model_name: 'Measure',
              operation: 'C',
              operation_date: String,
            },
            relationships: {
              record: {
                data: {
                  id: measure.measure_sid.to_s,
                  type: 'measure',
                },
              },
            },
          },
          {
            id: String,
            type: 'change',
            attributes: {
              oid: Integer,
              model_name: 'Chapter',
              operation: 'C',
              operation_date: String,
            },
            relationships: {
              record: {
                data: {
                  id: chapter.goods_nomenclature_sid.to_s,
                  type: 'chapter',
                },
              },
            },
          },
          {
            id: String,
            type: 'change',
            attributes: {
              oid: Integer,
              model_name: 'Chapter',
              operation: 'U',
              operation_date: String,
            },
            relationships: {
              record: {
                data: {
                  id: chapter.goods_nomenclature_sid.to_s,
                  type: 'chapter',
                },
              },
            },
          },
        ],
        included: [
          {
            id: measure.measure_sid.to_s,
            type: 'measure',
            attributes: {
              id: measure.measure_sid,
              origin: measure.origin,
              import: measure.import,
              goods_nomenclature_item_id: measure.goods_nomenclature_item_id,
            },
            relationships: {
              geographical_area: {
                data: {
                  id: measure.geographical_area.id.to_s,
                  type: 'geographical_area',
                },
              },
              measure_type: {
                data: {
                  id: measure.measure_type.id.to_s,
                  type: 'measure_type',
                },
              },
            },
          },
          {
            id: measure.geographical_area.id.to_s,
            type: 'geographical_area',
            attributes: {
              id: measure.geographical_area.id.to_s,
              description: measure.geographical_area.geographical_area_description.description,
            },
          },
          {
            id: measure.measure_type.id.to_s,
            type: 'measure_type',
            attributes: {
              id: measure.measure_type.id.to_s,
              description: measure.measure_type.description,
            },
          },
          {
            id: chapter.goods_nomenclature_sid.to_s,
            type: 'chapter',
            attributes: {
              description: chapter.description,
              goods_nomenclature_item_id: chapter.goods_nomenclature_item_id,
              validity_start_date: chapter.validity_start_date,
              validity_end_date: chapter.validity_end_date,
            },
          },
        ],
      }
    end

    it 'returns chapter changes' do
      get :changes, params: { id: chapter }, format: :json

      expect(response.body).to match_json_expression pattern
    end
  end

  context 'changes happened before requested date' do
    let(:chapter) do
      create :chapter, :with_section, :with_note,
             operation_date: Date.current
    end
    let(:heading) { create :heading, goods_nomenclature_item_id: "#{chapter.goods_nomenclature_item_id.first(2)}20000000" }
    let!(:measure) do
      create :measure,
             :with_measure_type,
             goods_nomenclature: heading,
             goods_nomenclature_sid: heading.goods_nomenclature_sid,
             goods_nomenclature_item_id: heading.goods_nomenclature_item_id,
             operation_date: Date.current
    end

    let!(:pattern) do
      {
        data: [],
        included: [],
      }
    end

    it 'does not include change records' do
      get :changes, params: { id: chapter, as_of: Date.yesterday }, format: :json

      expect(response.body).to match_json_expression pattern
    end
  end

  context 'changes include deleted record' do
    let(:chapter) do
      create :chapter, :with_section, :with_note,
             operation_date: Date.current
    end

    let(:heading) { create :heading, goods_nomenclature_item_id: "#{chapter.goods_nomenclature_item_id.first(2)}20000000" }
    let!(:measure) do
      create :measure,
             :with_measure_type,
             goods_nomenclature: heading,
             goods_nomenclature_sid: heading.goods_nomenclature_sid,
             goods_nomenclature_item_id: heading.goods_nomenclature_item_id,
             operation_date: Date.current
    end

    let(:pattern) do
      {
        data: [
          {
            id: String,
            type: 'change',
            attributes: {
              oid: Integer,
              model_name: 'Measure',
              operation: 'C',
              operation_date: String,
            },
            relationships: {
              record: {
                data: {
                  id: measure.measure_sid.to_s,
                  type: 'measure',
                },
              },
            },
          },
          {
            id: String,
            type: 'change',
            attributes: {
              oid: Integer,
              model_name: 'Measure',
              operation: 'D',
              operation_date: String,
            },
            relationships: {
              record: {
                data: {
                  id: measure.measure_sid.to_s,
                  type: 'measure',
                },
              },
            },
          },
          {
            id: String,
            type: 'change',
            attributes: {
              oid: Integer,
              model_name: 'Chapter',
              operation: 'C',
              operation_date: String,
            },
            relationships: {
              record: {
                data: {
                  id: chapter.goods_nomenclature_sid.to_s,
                  type: 'chapter',
                },
              },
            },
          },
          {
            id: String,
            type: 'change',
            attributes: {
              oid: Integer,
              model_name: 'Chapter',
              operation: 'U',
              operation_date: String,
            },
            relationships: {
              record: {
                data: {
                  id: chapter.goods_nomenclature_sid.to_s,
                  type: 'chapter',
                },
              },
            },
          },
        ],
        included: [
          {
            id: measure.measure_sid.to_s,
            type: 'measure',
            attributes: {
              id: measure.measure_sid,
              origin: measure.origin,
              import: measure.import,
              goods_nomenclature_item_id: measure.goods_nomenclature_item_id,
            },
            relationships: {
              geographical_area: {
                data: {
                  id: measure.geographical_area.id.to_s,
                  type: 'geographical_area',
                },
              },
              measure_type: {
                data: {
                  id: measure.measure_type.id.to_s,
                  type: 'measure_type',
                },
              },
            },
          },
          {
            id: measure.geographical_area.id.to_s,
            type: 'geographical_area',
            attributes: {
              id: measure.geographical_area.id.to_s,
              description: measure.geographical_area.geographical_area_description.description,
            },
          },
          {
            id: measure.measure_type.id.to_s,
            type: 'measure_type',
            attributes: {
              id: measure.measure_type.id.to_s,
              description: measure.measure_type.description,
            },
          },
          {
            id: chapter.goods_nomenclature_sid.to_s,
            type: 'chapter',
            attributes: {
              description: chapter.description,
              goods_nomenclature_item_id: chapter.goods_nomenclature_item_id,
              validity_start_date: chapter.validity_start_date,
              validity_end_date: chapter.validity_end_date,
            },
          },
        ],
      }
    end

    before { measure.destroy }

    it 'renders record attributes' do
      get :changes, params: { id: chapter }, format: :json

      expect(response.body).to match_json_expression pattern
    end
  end
end
