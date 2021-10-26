RSpec.describe Api::V2::GeographicalAreasController do
  before do
    allow(Rails.cache).to receive(:fetch).and_call_original
  end

  let!(:country_geographical_area) { create(:geographical_area, :with_description, :country) }
  let!(:group_geographical_area) { create(:geographical_area, :with_description, :group) }
  let!(:region_geographical_area) { create(:geographical_area, :with_description, :region) }

  let(:actual_date) { Time.zone.today }

  describe 'GET countries' do
    subject(:do_response) { get :countries }

    let(:pattern) do
      {
        data: [
          { id: String, type: String, attributes: { id: String, description: String, geographical_area_id: String }, relationships: { children_geographical_areas: { data: [] } } },
          { id: String, type: String, attributes: { id: String, description: String, geographical_area_id: String }, relationships: { children_geographical_areas: { data: [] } } },
        ],
        included: Array,
      }
    end

    it { expect(do_response.body).to match_json_expression(pattern) }

    it { expect(do_response.body).to include(region_geographical_area.geographical_area_id) }

    it 'caches the serialized countries' do
      do_response

      expect(Rails.cache).to have_received(:fetch).with("_geographical-areas-countries-#{actual_date}", expires_in: 24.hours)
    end
  end

  describe 'GET index' do
    subject(:do_response) { get :index }

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

    it { expect(do_response.body).to match_json_expression(pattern) }

    it 'caches the serialized geographical_areas' do
      do_response

      expect(Rails.cache).to have_received(:fetch).with("_geographical-areas-index-#{actual_date}", expires_in: 24.hours)
    end

    describe 'with children geographical areas' do
      before do
        create(
          :geographical_area_membership,
          geographical_area_sid: country_geographical_area.geographical_area_sid,
          geographical_area_group_sid: group_geographical_area.geographical_area_sid,
        )
        create(
          :geographical_area_membership,
          geographical_area_sid: region_geographical_area.geographical_area_sid,
          geographical_area_group_sid: group_geographical_area.geographical_area_sid,
        )
      end

      let(:pattern) do
        {
          data: [
            {
              id: country_geographical_area.geographical_area_id,
              type: 'geographical_area',
              attributes: {
                id: country_geographical_area.geographical_area_id,
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
              id: region_geographical_area.geographical_area_id,
              type: 'geographical_area',
              attributes: {
                id: region_geographical_area.geographical_area_id,
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
              id: group_geographical_area.geographical_area_id,
              type: 'geographical_area',
              attributes: {
                id: group_geographical_area.geographical_area_id,
                description: String,
                geographical_area_id: String,
              },
              relationships: {
                children_geographical_areas: {
                  data: [
                    {
                      id: country_geographical_area.geographical_area_id,
                      type: 'geographical_area',
                    },
                    {
                      id: region_geographical_area.geographical_area_id,
                      type: 'geographical_area',
                    },
                  ],
                },
              },
            },
          ],
          included: [
            {
              id: country_geographical_area.geographical_area_id,
              type: 'geographical_area',
              attributes: {
                id: country_geographical_area.geographical_area_id,
                description: String,
                geographical_area_id: String,
              },
              relationships: Hash,
            },
            {
              id: region_geographical_area.geographical_area_id,
              type: 'geographical_area',
              attributes: {
                id: region_geographical_area.geographical_area_id,
                description: String,
                geographical_area_id: String,
              },
              relationships: Hash,
            },
          ],
        }
      end

      it { expect(do_response.body).to match_json_expression(pattern) }
    end
  end
end
