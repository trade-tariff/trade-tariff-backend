RSpec.describe HeadingService::Serialization::NsNondeclarableService do
  describe 'MEASURES_EAGER_LOAD' do
    # geographical_area_descriptions must be eagerly loaded alongside geographical_area.
    # Without it, serialising a measure's geographical area fires one JOIN query per
    # measure — the source of the N+1 observed after the nightly TARIC sync triggers
    # PrecacheHeadingsWorker across all headings.
    it 'includes geographical_area_descriptions nested under geographical_area' do
      expect(described_class::MEASURES_EAGER_LOAD).to include(
        geographical_area: :geographical_area_descriptions,
      )
    end
  end
end
