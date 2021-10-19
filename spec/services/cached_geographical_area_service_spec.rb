RSpec.describe CachedGeographicalAreaService do
  subject(:service) { described_class.new(actual_date, countries: countries) }

  let(:actual_date) { Time.zone.today }
  let(:countries) { false }

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

    before do
      allow(Rails.cache).to receive(:fetch).and_call_original

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

        expected_ids = service.call[:data].map { |area| area[:id] }

        expect(expected_ids).to eq(%w[AA BA])
      end
    end

    context 'when fetching geographical areas' do
      let(:geographical_area) { create(:geographical_area, :group, geographical_area_id: 'BA') }
      let(:countries) { false }

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

        expected_ids = service.call[:data].map { |area| area[:id] }

        expect(expected_ids).to eq(%w[AA BA])
      end
    end

    context 'when on the xi service' do
      before { allow(TradeTariffBackend).to receive(:xi?).and_return(true) }

      let(:geographical_area) { create(:geographical_area, :country, geographical_area_id: 'GB') }
      let(:excluded_geographical_area) { create(:geographical_area, :country, geographical_area_id: 'XU') }

      it 'excludes XU' do
        excluded_geographical_area
        no_xu = service.call[:data].select { |country| country[:id] == 'XU' }.empty?
        expect(no_xu).to be(true)
      end
    end

    context 'when not on the xi service' do
      before do
        allow(TradeTariffBackend).to receive(:xi?).and_return(false)

        %w[GB XU XI].map do |excluded_id|
          create(:geographical_area, :country, geographical_area_id: excluded_id)
        end
      end

      let(:geographical_area) { create(:geographical_area, :country, geographical_area_id: 'GB') }

      it 'excludes XU' do
        no_excluded_areas = service.call[:data].select { |country| country[:id].in?(%w[GB XU XI]) }

        expect(no_excluded_areas).to be_empty
      end
    end
  end
end
