RSpec.describe MeursingMeasureFinderService do
  subject(:service) { described_class.new(root_measure, additional_code_id) }

  let(:root_measure) { create(:measure) }

  let(:additional_code_id) { '000' }

  describe '#call' do
    before do
      meursing_measure # Running factories within an around callback does not trigger the database cleaner
    end

    around do |example|
      TimeMachine.now { example.run }
    end

    context 'when there are matching meursing measures' do
      let(:meursing_measure) do
        create(
          :meursing_measure,
          root_measure: root_measure,
          geographical_area_id: GeographicalArea::ERGA_OMNES_ID, # Implicitly validates extensive measure contained geographical area filtering
        )
      end

      it { expect(service.call.map(&:pk)).to eq([meursing_measure.pk]) }
    end

    context 'when there are no matching meursing measures' do
      let(:meursing_measure) { create(:meursing_measure) }

      it { expect(service.call).to eq([]) }
    end
  end
end
