require 'rails_helper'

describe Api::V1::SearchController, 'POST #search' do
  describe 'exact matching' do
    let(:chapter) { create :chapter }
    let(:pattern) do
      {
        type: 'exact_match',
        entry: {
          endpoint: 'chapters',
          id: chapter.to_param,
        },
      }
    end

    it 'returns exact match endpoint and indetifier if query for exact record' do
      post :search, params: { q: chapter.to_param, as_of: chapter.validity_start_date }
      expect(response.status).to eq(200)
      expect(response.body).to match_json_expression pattern
    end
  end

  describe 'fuzzy matching' do
    let(:chapter) { create :chapter, :with_description, description: 'horse', validity_start_date: Date.current }
    let(:pattern) do
      {
        type: 'fuzzy_match',
        reference_match: {
          commodities: Array,
          headings: Array,
          chapters: Array,
          sections: Array,
        },
        goods_nomenclature_match: {
          commodities: Array,
          headings: Array,
          chapters: Array,
          sections: Array,
        },
      }
    end

    it 'returns records grouped by type' do
      post :search, params: { q: chapter.description, as_of: chapter.validity_start_date }
      expect(response.status).to eq(200)
      expect(response.body).to match_json_expression pattern
    end
  end

  describe 'null match' do
    let(:pattern) do
      {
        type: 'null_match',
        reference_match: {
          commodities: [],
          headings: [],
          chapters: [],
          sections: [],
        },
        goods_nomenclature_match: {
          commodities: [],
          headings: [],
          chapters: [],
          sections: [],
        },
      }
    end

    it 'returns empty list' do
      post :search
      expect(response.status).to eq(200)
      expect(response.body).to match_json_expression pattern
    end
  end
end

describe Api::V1::SearchController, 'GET #suggestions' do
  render_views

  let!(:commodity1) { create :commodity }
  let!(:commodity2) { create :commodity }
  let!(:commodity3) { create :commodity }

  let(:pattern) do
    [{ value: String }, { value: String }, { value: String }]
  end

  it 'returns rendered suggestions' do
    get :suggestions, format: :json

    expect(response.body).to match_json_expression pattern
  end

  it 'includes commodity 2' do
    get :suggestions, format: :json

    expect(response.body.to_s).to include(commodity2.goods_nomenclature_item_id)
  end

  describe 'machine timed' do
    let!(:commodity1) { create :commodity, validity_end_date: '2015-12-31', validity_start_date: '2000-12-31' }
    let!(:commodity2) { create :commodity, validity_end_date: '2015-12-01', validity_start_date: '2000-12-31' }
    let!(:commodity3) { create :commodity, validity_end_date: '2015-12-31', validity_start_date: '2000-12-31' }

    let(:pattern) do
      [{ value: String }, { value: String }]
    end

    before do
      get :suggestions, params: { as_of: '2015-12-04' }, format: :json
    end

    it 'returns rendered records' do
      expect(response.body).to match_json_expression pattern
    end

    it 'includes commodity 1' do
      expect(response.body.to_s).to include(commodity1.goods_nomenclature_item_id)
    end

    it "doesn't include commodity 2" do
      expect(response.body.to_s).not_to include(commodity2.goods_nomenclature_item_id)
    end
  end

  describe 'with search_references' do
    let(:heading) { create :heading }
    let!(:search_reference_heading) do
      create :search_reference, heading: heading, heading_id: heading.to_param, title: 'test heading 1'
    end

    it 'includes search_reference_heading' do
      get :suggestions, format: :json

      expect(response.body.to_s).to include(search_reference_heading.title)
    end
  end
end
