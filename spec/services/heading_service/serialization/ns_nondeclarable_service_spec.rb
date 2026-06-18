RSpec.describe HeadingService::Serialization::NsNondeclarableService do
  describe '#serializable_hash' do
    around do |example|
      Thread.current[:jsonapi_query_options] = {
        include_requested: true,
        include: [],
        fields: { heading: %i[goods_nomenclature_item_id] },
      }

      example.run
    ensure
      Thread.current[:jsonapi_query_options] = nil
    end

    it 'does not reload the full heading eager graph when sparse fields do not need it' do
      heading = create(:heading, :with_chapter)
      allow(Heading).to receive(:actual).and_call_original

      described_class.new(heading).serializable_hash

      expect(Heading).not_to have_received(:actual)
    end
  end

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
