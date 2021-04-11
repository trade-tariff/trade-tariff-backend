require 'rails_helper'

RSpec.describe CachedGeographicalAreaService do
  subject(:service) { described_class.new(actual_date, countries) }

  let(:actual_date) { Time.zone.today }
  let(:countries) { false }
  let(:xi_service) { false }
  let(:geographical_area) { create(:geographical_area, :country, geographical_area_id: 'RO') }
  let(:excluded_geographical_area) { create(:geographical_area, :country, geographical_area_id: 'JE') }

  describe '#call' do
    let(:pattern) do
      {
        data: [
          {
            id: String,
            type: 'geographical_area',
            attributes: Hash,
            relationships: {
              children_geographical_areas: Hash,
            },
          },
        ],
        included: [],
      }
    end
    let(:expected_ordered_ids) { service.call[:data].map { |geographical_area| geographical_area[:id] } }

    before do
      allow(Rails.cache).to receive(:fetch).and_call_original
      allow(TradeTariffBackend).to receive(:xi?).and_return(xi_service)

      geographical_area
    end

    it 'excludes globally excluded geographical area ids' do
      excluded_geographical_area
      no_je = service.call[:data].select { |country| country[:id] == 'JE' }.empty?
      expect(no_je).to be(true)
    end

    context 'when fetching geographical area countries' do
      let(:countries) { true }
      let(:geographical_area) { create(:geographical_area, :country, geographical_area_id: 'BA') }

      it 'returns a correctly serialized hash' do
        expect(service.call.to_json).to match_json_expression pattern
      end

      it 'uses the correct cache key' do
        expected_key = "_geographical-areas-countries-#{actual_date}"
        service.call
        expect(Rails.cache).to have_received(:fetch).with(expected_key, expires_in: 24.hours)
      end

      it 'sorts the geographical areas by their id' do
        create(:geographical_area, :country, geographical_area_id: 'AA')

        expect(expected_ordered_ids).to eq(%w[AA BA])
      end
    end

    context 'when fetching geographical areas' do
      let(:geographical_area) { create(:geographical_area, :group, geographical_area_id: 'BA') }
      let(:countries) { false }
      let(:expected_ordered_ids) { service.call[:data].map { |geographical_area| geographical_area[:id] } }

      it 'returns a correctly serialized hash' do
        expect(service.call.to_json).to match_json_expression pattern
      end

      it 'uses the correct cache key' do
        expected_key = "_geographical-areas-index-#{actual_date}"
        service.call
        expect(Rails.cache).to have_received(:fetch).with(expected_key, expires_in: 24.hours)
      end

      it 'sorts the geographical areas by their id' do
        create(:geographical_area, :group, geographical_area_id: 'AA')

        expect(expected_ordered_ids).to eq(%w[AA BA])
      end
    end

    context 'when on the xi service' do
      let(:xi_service) { true }
      let(:geographical_area) { create(:geographical_area, :country, geographical_area_id: 'GB') }
      let(:excluded_geographical_area) { create(:geographical_area, :country, geographical_area_id: 'XU') }

      it 'excludes XU' do
        excluded_geographical_area
        no_xu = service.call[:data].select { |country| country[:id] == 'XU' }.empty?
        expect(no_xu).to be(true)
      end
    end

    context 'when not on the xi service' do
      let(:xi_service) { false }
      let(:geographical_area) { create(:geographical_area, :country, geographical_area_id: 'GB') }
      let(:excluded_geographical_area_ids) { %w[GB XU XI] }

      let(:excluded_geographical_areas) do
        excluded_geographical_area_ids.map do |excluded_id|
          create(:geographical_area, :country, geographical_area_id: excluded_id)
        end
      end

      it 'excludes XU' do
        excluded_geographical_areas
        no_excluded_areas = service.call[:data].select { |country| country[:id].in?(excluded_geographical_area_ids) }.empty?
        expect(no_excluded_areas).to be(true)
      end
    end
  end
end
