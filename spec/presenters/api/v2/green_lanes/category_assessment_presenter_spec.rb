RSpec.describe Api::V2::GreenLanes::CategoryAssessmentPresenter do
  subject(:presented) { described_class.new(assessment, assessment.measures) }

  let(:assessment) { create :category_assessment, :with_measures }

  it { is_expected.to have_attributes id: assessment.id }
  it { is_expected.to have_attributes measure_ids: assessment.measures.map(&:measure_sid) }

  describe '.wrap' do
    subject(:wrapped) { described_class.wrap [assessment] }

    it { is_expected.to have_attributes length: 1 }
    it { is_expected.to all be_instance_of described_class }

    context 'with first presented category assessment' do
      subject { wrapped.first }

      it { is_expected.to have_attributes id: assessment.id }
      it { is_expected.to have_attributes measure_ids: assessment.measures.map(&:measure_sid) }
    end
  end

  describe '#measures' do
    subject(:measures) { presented.measures }

    it { is_expected.to all be_instance_of Api::V2::GreenLanes::MeasurePresenter }
    it { expect(measures.map(&:measure_sid)).to eq assessment.measures.map(&:measure_sid) }
  end
end
