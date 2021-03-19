require 'rails_helper'

RSpec.describe CachedGeographicalAreaService do
  subject(:service) { described_class.new(actual_date, countries) }

  let(:actual_date) { Time.zone.today }
  let(:countries) { false }

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

    before do
      allow(Rails.cache).to receive(:fetch).and_call_original
      geographical_area
    end

    context 'when fetching geographical area countries' do
      let(:geographical_area) { create(:geographical_area, :country) }
      let(:countries) { true }

      it 'returns a correctly serialized hash' do
        expect(service.call.to_json).to match_json_expression pattern
      end

      it 'uses the correct cache key' do
        expected_key = "_geographical-areas-countries-#{actual_date}"
        service.call
        expect(Rails.cache).to have_received(:fetch).with(expected_key, expires_in: 24.hours)
      end
    end

    context 'when fetching geographical areas' do
      let(:geographical_area) { create(:geographical_area, :group) }
      let(:countries) { false }

      it 'returns a correctly serialized hash' do
        expect(service.call.to_json).to match_json_expression pattern
      end

      it 'uses the correct cache key' do
        expected_key = "_geographical-areas-index-#{actual_date}"
        service.call
        expect(Rails.cache).to have_received(:fetch).with(expected_key, expires_in: 24.hours)
      end
    end
  end
end
