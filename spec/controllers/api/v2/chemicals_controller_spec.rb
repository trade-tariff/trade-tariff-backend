RSpec.describe Api::V2::ChemicalsController, type: :controller do
  routes { V2Api.routes }

  let(:chemical1) { create :chemical, :with_name }
  let(:goods_nomenclature) { create :goods_nomenclature }
  let(:chemical_gn_association) { create :chemicals_goods_nomenclatures, chemical_id: chemical1.id, goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid }

  let(:api_short_object_pattern) do
    {
      data: [
        {
          id: String,
          type: 'chemical',
          attributes: {
            id: Integer,
            cas: String,
            name: String,
          },
        },
      ].ignore_extra_values!,
    }
  end

  let(:api_long_object_pattern) do
    {
      data: {
        id: String,
        type: 'chemical',
        attributes: {
          id: Integer,
          cas: String,
          name: String,
        },
        relationships: {
          goods_nomenclatures: {
            data: [
              {
                id: String,
                type: 'goods_nomenclature',
              },
            ],
          },
          chemical_names: {
            data: [
              {
                id: String,
                type: 'chemical_name',
              },
            ],
          },
        },
        links: {
          uri: String,
        },
      },
      included: [
        {
          id: String,
          type: 'chemical_name',
          attributes: {
            name: String,
            chemical_id: Integer,
          },
        },
        {
          id: String,
          type: 'goods_nomenclature',
          attributes: {
            goods_nomenclature_item_id: String,
            goods_nomenclature_sid: Integer,
            description: String,
            number_indents: Integer,
            producline_suffix: String,
            href: String,
          },
        },
      ],
    }
  end

  let(:search_long_collection_pattern) do
    {
      data: [
        {
          id: String,
          type: 'chemical',
          attributes: {
            id: Integer,
            cas: String,
            name: String,
          },
          relationships: {
            goods_nomenclatures: {
              data: [
                {
                  id: String,
                  type: 'goods_nomenclature',
                },
              ],
            },
            chemical_names: {
              data: [
                {
                  id: String,
                  type: 'chemical_name',
                },
              ],
            },
          },
        },
      ],
      included: [
        {
          id: String,
          type: 'chemical_name',
          attributes: {
            name: String,
            chemical_id: Integer,
          },
        },
        {
          id: String,
          type: 'goods_nomenclature',
          attributes: {
            goods_nomenclature_item_id: String,
            goods_nomenclature_sid: Integer,
            description: String,
            number_indents: Integer,
            producline_suffix: String,
            href: String,
          },
        },
      ],
      meta: {
        pagination: {
          page: Integer,
          per_page: Integer,
          total_count: Integer,
        },
      },
    }
  end

  before { chemical_gn_association }

  context 'without parameters, GET #index' do
    it 'returns chemicals as a collection' do
      get :index, format: :json

      expect(response.body).to match_json_expression api_short_object_pattern
    end
  end

  context 'with the `:id` (i.e., CAS number) parameter, GET #show' do
    it 'returns one record' do
      get :show, params: { id: chemical1.cas }, format: :json

      expect(response.body).to match_json_expression api_long_object_pattern
    end
  end

  context 'with the `:cas` (i.e., CAS number) parameter, GET #search' do
    it 'returns all matching records (which should normally be one record), as a collection' do
      get :search, params: { cas: chemical1.cas }, format: :json

      expect(response.body).to match_json_expression search_long_collection_pattern
    end
  end

  context 'with the `:name` (i.e., partial chemical name) parameter, GET #search' do
    it 'returns all matching records as a collection' do
      get :search, params: { name: chemical1.name[1..5] }, format: :json

      expect(response.body).to match_json_expression search_long_collection_pattern
    end
  end

  # Invadid params should return 404s:

  context 'with an invalid `:id` parameter, GET #show' do
    it 'returns 404' do
      get :show, params: { id: 'FOOBAR' }, format: :json

      expect(response.code.to_i).to eq 404
    end
  end

  context 'with an invalid `:cas` parameter, GET #search' do
    it 'returns 404' do
      get :search, params: { cas: 'FOOBAR' }, format: :json

      expect(response.code.to_i).to eq 404
    end
  end

  context 'with an invalid `:name` parameter, GET #search' do
    it 'returns 404' do
      get :search, params: { name: 'FOOBAR' }, format: :json

      expect(response.code.to_i).to eq 404
    end
  end
end
