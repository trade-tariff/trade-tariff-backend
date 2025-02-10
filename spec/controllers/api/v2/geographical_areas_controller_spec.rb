RSpec.describe Api::V2::GeographicalAreasController do
  routes { V2Api.routes }

  before do
    Rails.cache.clear
    allow(Rails.cache).to receive(:fetch).and_call_original

    country_geographical_area
    group_geographical_area
    region_geographical_area
    globally_excluded_area
  end

  let(:country_geographical_area) { create(:geographical_area, :with_description, :country) }
  let(:group_geographical_area) { create(:geographical_area, :with_description, :group) }
  let(:region_geographical_area) { create(:geographical_area, :with_description, :region) }
  let(:globally_excluded_area) { create(:geographical_area, :with_description, :globally_excluded) }

  let(:actual_date) { Time.zone.today }

  describe 'GET countries' do
    subject(:do_response) { get :countries }

    it { expect(do_response.body).to include(region_geographical_area.geographical_area_id) }
    it { expect(do_response.body).to include(country_geographical_area.geographical_area_id) }
    it { expect(do_response.body).not_to include(group_geographical_area.geographical_area_id) }
    it { expect(do_response.body).not_to include(globally_excluded_area.geographical_area_id) }

    it 'caches the serialized countries' do
      do_response

      expect(Rails.cache).to have_received(:fetch).with("_geographical-areas-#{actual_date}-true-false", expires_in: 24.hours)
    end

    context 'when the exclude none filter is passed' do
      subject(:do_response) { get :countries, params: { filter: { exclude_none: 'true' } } }

      it { expect(do_response.body).to include(region_geographical_area.geographical_area_id) }
      it { expect(do_response.body).to include(country_geographical_area.geographical_area_id) }
      it { expect(do_response.body).to include(globally_excluded_area.geographical_area_id) }
      it { expect(do_response.body).not_to include(group_geographical_area.geographical_area_id) }

      it 'caches the serialized geographical_areas' do
        do_response

        expect(Rails.cache).to have_received(:fetch).with("_geographical-areas-#{actual_date}-true-true", expires_in: 24.hours)
      end
    end
  end

  describe 'GET index' do
    subject(:do_response) { get :index }

    it { expect(do_response.body).to include(region_geographical_area.geographical_area_id) }
    it { expect(do_response.body).to include(country_geographical_area.geographical_area_id) }
    it { expect(do_response.body).to include(group_geographical_area.geographical_area_id) }
    it { expect(do_response.body).not_to include(globally_excluded_area.geographical_area_id) }

    it 'caches the serialized geographical_areas' do
      do_response

      expect(Rails.cache).to have_received(:fetch).with("_geographical-areas-#{actual_date}-false-false", expires_in: 24.hours)
    end

    context 'when there are children geographical areas' do
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

      it 'returns the correct contained areas' do
        geographical_area_group = JSON.parse(do_response.body)['data'].find { |area| area['id'] == '1011' }

        actual_children_geographical_areas = geographical_area_group
          .dig('relationships', 'children_geographical_areas', 'data')
          .pluck('id')
          .sort

        expected_children_geographical_areas = [
          country_geographical_area.geographical_area_id,
          region_geographical_area.geographical_area_id,
        ].sort

        expect(actual_children_geographical_areas).to eq(expected_children_geographical_areas)
      end
    end

    context 'when the exclude none filter is passed' do
      subject(:do_response) { get :index, params: { filter: { exclude_none: 'true' } } }

      it { expect(do_response.body).to include(region_geographical_area.geographical_area_id) }
      it { expect(do_response.body).to include(country_geographical_area.geographical_area_id) }
      it { expect(do_response.body).to include(globally_excluded_area.geographical_area_id) }
      it { expect(do_response.body).to include(group_geographical_area.geographical_area_id) }

      it 'caches the serialized geographical_areas' do
        do_response

        expect(Rails.cache).to have_received(:fetch).with("_geographical-areas-#{actual_date}-false-true", expires_in: 24.hours)
      end
    end
  end

  describe 'GET show' do
    subject(:do_response) { get :show, params: { id: country_geographical_area.geographical_area_id } }

    it { expect(do_response.body).to include(country_geographical_area.geographical_area_id) }
  end
end
