require 'rails_helper'

describe Api::V1::ChaptersController, 'GET #show' do
  render_views

  let!(:chapter) { create :chapter, :with_description, :with_section, goods_nomenclature_item_id: '1100000000' }
  let!(:section_note) { create :section_note, section: chapter.section }

  let(:pattern) do
    {
      goods_nomenclature_item_id: chapter.code,
      description: String,
      headings: Array,
      section: {
        section_note: String,
      }.ignore_extra_keys!,
      _response_info: Hash,
    }.ignore_extra_keys!
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

describe Api::V1::ChaptersController, 'GET #index' do
  render_views

  let!(:chapter1) { create :chapter, :with_section, :with_note }
  let!(:chapter2) { create :chapter, :with_section, :with_note }

  let(:pattern) do
    [
      { goods_nomenclature_item_id: String, chapter_note_id: Integer },
      { goods_nomenclature_item_id: String, chapter_note_id: Integer },
    ]
  end

  it 'returns rendered records' do
    get :index, format: :json

    expect(response.body).to match_json_expression pattern
  end
end

describe Api::V1::ChaptersController, 'GET #changes' do
  render_views

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
      [
        {
          oid: Integer,
          model_name: 'Measure',
          record: {
            measure_type: {
              description: measure.measure_type.description,
            }.ignore_extra_keys!,
          }.ignore_extra_keys!,
        }.ignore_extra_keys!,
        {
          oid: Integer,
          model_name: 'Chapter',
          operation: String,
          operation_date: String,
          record: {
            description: String,
            goods_nomenclature_item_id: String,
            validity_start_date: String,
            validity_end_date: nil,
          },
        },
      ].ignore_extra_values!
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

    it 'does not include change records' do
      get :changes, params: { id: chapter, as_of: Date.yesterday }, format: :json

      expect(response.body).to match_json_expression []
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
      [
        {
          oid: Integer,
          model_name: 'Measure',
          operation: 'D',
          record: {
            goods_nomenclature_item_id: measure.goods_nomenclature_item_id,
            measure_type: {
              description: measure.measure_type.description,
            }.ignore_extra_keys!,
          }.ignore_extra_keys!,
        }.ignore_extra_keys!,
        {
          oid: Integer,
          model_name: 'Chapter',
          operation: String,
          operation_date: String,
          record: {
            description: String,
            goods_nomenclature_item_id: String,
            validity_start_date: String,
            validity_end_date: nil,
          },
        },
      ].ignore_extra_values!
    end

    before { measure.destroy }

    it 'renders record attributes' do
      get :changes, params: { id: chapter }, format: :json

      expect(response.body).to match_json_expression pattern
    end
  end
end
