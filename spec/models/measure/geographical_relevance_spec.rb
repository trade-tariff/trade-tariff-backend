RSpec.describe Measure::GeographicalRelevance do
  subject(:relevance) { described_class.new(measure) }

  let(:erga_omnes_id) { GeographicalArea::ERGA_OMNES_ID }

  # Builds a minimal measure double. excluded_ids is the flat list of
  # geographical_area_ids that the measure explicitly excludes.
  def measure_double(geo_id:, national: false, meursing: false, excluded_ids: [], contained_ids: [], referenced_ids: nil)
    geo_area = instance_double(
      GeographicalArea,
      contained_geographical_areas: instance_double(Sequel::Dataset, pluck: referenced_ids || contained_ids),
      referenced: nil,
    )

    excluded_areas = excluded_ids.map do |id|
      area = instance_double(GeographicalArea, candidate_excluded_geographical_area_ids: [id])
      instance_double(GeographicalArea, referenced_or_self: area)
    end

    measure_type = instance_double(MeasureType, meursing?: meursing)

    instance_double(
      Measure,
      geographical_area_id: geo_id,
      national?: national,
      measure_type: measure_type,
      excluded_geographical_areas: excluded_areas,
      geographical_area: geo_area,
    )
  end

  describe '#relevant_for?' do
    context 'when the country is explicitly excluded' do
      let(:measure) { measure_double(geo_id: erga_omnes_id, excluded_ids: ['FR']) }

      it 'returns false' do
        expect(relevance.relevant_for?('FR')).to be false
      end
    end

    context 'when the measure is erga omnes and national' do
      let(:measure) { measure_double(geo_id: erga_omnes_id, national: true) }

      it 'returns true for any country' do
        expect(relevance.relevant_for?('DE')).to be true
      end
    end

    context 'when the measure is erga omnes with a meursing measure type' do
      let(:measure) { measure_double(geo_id: erga_omnes_id, meursing: true) }

      it 'returns true for any country' do
        expect(relevance.relevant_for?('JP')).to be true
      end
    end

    context 'when the measure has no geographical area' do
      let(:measure) { measure_double(geo_id: nil) }

      it 'returns true (applies globally)' do
        expect(relevance.relevant_for?('US')).to be true
      end
    end

    context 'when the measure geographical area matches the country directly' do
      let(:measure) { measure_double(geo_id: 'FR') }

      it 'returns true' do
        expect(relevance.relevant_for?('FR')).to be true
      end
    end

    context 'when the country is in the measure geographical area group' do
      let(:measure) { measure_double(geo_id: 'EU', contained_ids: ['FR', 'DE', 'IT']) }

      it 'returns true for a contained country' do
        expect(relevance.relevant_for?('FR')).to be true
      end

      it 'returns false for a country not in the group' do
        expect(relevance.relevant_for?('US')).to be false
      end
    end

    context 'when the geographical area has a referenced group with members' do
      let(:measure) { measure_double(geo_id: 'EU', referenced_ids: ['FR', 'DE']) }

      it 'returns true for a member of the referenced group' do
        expect(relevance.relevant_for?('DE')).to be true
      end
    end

    context 'when the measure has a non-matching, non-erga-omnes geographical area' do
      let(:measure) { measure_double(geo_id: 'US', contained_ids: []) }

      it 'returns false for a different country' do
        expect(relevance.relevant_for?('FR')).to be false
      end
    end
  end
end
