describe Api::V2::GeographicalAreasController, 'GET #countries' do
  let!(:geographical_area1) do
    create :geographical_area,
           :with_description,
           :country
  end
  let!(:geographical_area2) do
    create :geographical_area,
           :with_description,
           :country
  end
  let!(:geographical_area3) do
    create :geographical_area,
           :with_description,
           geographical_code: '2'
  end

  let(:pattern) do
    {
      data: [
        { id: String, type: String, attributes: { id: String, description: String, geographical_area_id: String }, relationships: { children_geographical_areas: { data: [] } } },
        { id: String, type: String, attributes: { id: String, description: String, geographical_area_id: String }, relationships: { children_geographical_areas: { data: [] } } },
        { id: String, type: String, attributes: { id: String, description: String, geographical_area_id: String }, relationships: { children_geographical_areas: { data: [] } } },
      ],
      included: Array,
    }
  end

  let(:actual_date) { Time.zone.today }

  before do
    allow(Rails.cache).to receive(:fetch).and_call_original
    allow(CachedGeographicalAreaService).to receive(:new).and_call_original
  end

  it 'calls the CachedGeographicalAreaService' do
    get :countries, format: :json

    expect(CachedGeographicalAreaService).to have_received(:new).with(actual_date, true)
  end

  it 'caches the serialized countries' do
    get :countries, format: :json

    expect(Rails.cache).to have_received(:fetch).with("_geographical-areas-countries-#{actual_date}", expires_in: 24.hours)
  end

  it 'caches the serialized geographical_areas' do
    get :index, format: :json

    expect(Rails.cache).to have_received(:fetch).with("_geographical-areas-index-#{actual_date}", expires_in: 24.hours)
  end

  it 'returns rendered records' do
    get :countries, format: :json

    expect(response.body).to match_json_expression pattern
  end

  it 'includes geographical areas with code 2' do
    get :countries, format: :json

    expect(response.body.to_s).to include(
      geographical_area3.geographical_area_id,
    )
  end

  describe 'machine timed' do
    let!(:geographical_area1) do
      create :geographical_area,
             :with_description,
             :country,
             validity_start_date: '2014-12-31 00:00:00',
             validity_end_date: '2015-12-31 00:00:00'
    end
    let!(:geographical_area2) do
      create :geographical_area,
             :with_description,
             :country,
             validity_start_date: '2014-12-01 00:00:00',
             validity_end_date: '2015-12-01 00:00:00'
    end
    let!(:geographical_area3) do
      create :geographical_area,
             :with_description,
             geographical_code: '2',
             validity_start_date: '2014-12-31 00:00:00',
             validity_end_date: '2015-12-31 00:00:00'
    end

    let(:pattern) do
      {
        data: [
          { id: String, type: String, attributes: { id: String, description: String, geographical_area_id: String }, relationships: { children_geographical_areas: { data: [] } } },
          { id: String, type: String, attributes: { id: String, description: String, geographical_area_id: String }, relationships: { children_geographical_areas: { data: [] } } },
        ],
        included: Array,
      }
    end

    before do
      get :countries,
          params: { as_of: '2015-12-04' },
          format: :json
    end

    it 'finds one area' do
      expect(response.body).to match_json_expression pattern
    end

    it 'includes area 1' do
      expect(response.body.to_s).to include(
        "\"id\":\"#{geographical_area1.geographical_area_id}\"",
      )
    end

    it "doesn't include area 2" do
      expect(response.body.to_s).not_to include(
        "\"id\":\"#{geographical_area2.geographical_area_id}\"",
      )
    end
  end

  describe 'with children geographical areas' do
    let!(:geographical_area1) do
      create :geographical_area,
             :with_description,
             :country
    end
    let!(:geographical_area2) do
      create :geographical_area,
             :with_description,
             :country
    end
    let!(:geographical_area3) do
      create :geographical_area,
             :with_description,
             geographical_code: '2'
    end
    let!(:parent_geographical_area) do
      create :geographical_area,
             :with_description,
             :group
    end
    let!(:geographical_area_membership1) do
      create :geographical_area_membership,
             geographical_area_sid: geographical_area1.geographical_area_sid,
             geographical_area_group_sid: parent_geographical_area.geographical_area_sid
    end
    let!(:geographical_area_membership3) do
      create :geographical_area_membership,
             geographical_area_sid: geographical_area3.geographical_area_sid,
             geographical_area_group_sid: parent_geographical_area.geographical_area_sid
    end

    let(:pattern) do
      {
        data: [
          {
            id: String,
            type: 'geographical_area',
            attributes: {
              id: String,
              description: String,
              geographical_area_id: String,
            },
            relationships: {
              children_geographical_areas: {
                data: [],
              },
            },
          },
          {
            id: String,
            type: 'geographical_area',
            attributes: {
              id: String,
              description: String,
              geographical_area_id: String,
            },
            relationships: {
              children_geographical_areas: {
                data: [],
              },
            },
          },
          {
            id: String,
            type: 'geographical_area',
            attributes: {
              id: String,
              description: String,
              geographical_area_id: String,
            },
            relationships: {
              children_geographical_areas: {
                data: [],
              },
            },
          },
          {
            id: parent_geographical_area.geographical_area_id,
            type: 'geographical_area',
            attributes: {
              id: parent_geographical_area.geographical_area_id,
              description: String,
              geographical_area_id: String,
            },
            relationships: {
              children_geographical_areas: {
                data: [
                  {
                    id: geographical_area1.geographical_area_id,
                    type: 'geographical_area',
                  },
                  {
                    id: geographical_area3.geographical_area_id,
                    type: 'geographical_area',
                  },
                ],
              },
            },
          },
        ],
        included: [
          {
            id: geographical_area1.geographical_area_id,
            type: 'geographical_area',
            attributes: {
              id: geographical_area1.geographical_area_id,
              description: String,
              geographical_area_id: String,
            },
            relationships: Hash,
          },
          {
            id: geographical_area3.geographical_area_id,
            type: 'geographical_area',
            attributes: {
              id: geographical_area3.geographical_area_id,
              description: String,
              geographical_area_id: String,
            },
            relationships: Hash,
          },
        ],
      }
    end

    it 'returns rendered records' do
      get :index, format: :json

      expect(response.body).to match_json_expression pattern
    end
  end
end
