RSpec.describe Api::V2::GreenLanes::CategoryAssessmentPresenter do
  subject(:presented) { described_class.new(assessment, *permutations.first) }

  let(:assessment) { create :category_assessment, :with_measures }

  let :permutations do
    GreenLanes::PermutationCalculatorService.new(assessment.measures).call
  end

  it { is_expected.to have_attributes id: /^[0-9a-f]{32}$/ }
  it { is_expected.to have_attributes category_assessment_id: assessment.id }
  it { is_expected.to have_attributes measure_ids: assessment.measures.map(&:measure_sid) }
  it { is_expected.to have_attributes category: /\d+/ }
  it { is_expected.to have_attributes theme: /\d+\.\d+\. \w+/ }

  describe '.wrap' do
    subject(:wrapped) { described_class.wrap [assessment] }

    it { is_expected.to have_attributes length: 1 }
    it { is_expected.to all be_instance_of described_class }

    context 'with first presented category assessment' do
      subject { wrapped.first }

      it { is_expected.to have_attributes id: /^[0-9a-f]{32}$/ }
      it { is_expected.to have_attributes measure_ids: assessment.measures.map(&:measure_sid) }
    end

    context 'with no measures' do
      let(:assessment) { create :category_assessment }

      it { is_expected.to be_empty }
    end
  end

  describe '#measures' do
    subject(:measures) { presented.measures }

    it { is_expected.to all be_instance_of Api::V2::GreenLanes::MeasurePresenter }
    it { expect(measures.map(&:measure_sid)).to eq assessment.measures.map(&:measure_sid) }
  end

  describe '#exemptions' do
    subject { presented.exemptions }

    let :certificates do
      create_pair(:certificate).each do |cert|
        create :measure_condition,
               measure_sid: assessment.measures.first.measure_sid,
               certificate_type_code: cert.certificate_type_code,
               certificate_code: cert.certificate_code
      end
    end

    let :additional_code do
      create(:additional_code).tap do |ad_code|
        assessment.measures.first.update additional_code: ad_code
      end
    end

    context 'with certificates' do
      before { certificates }

      it { is_expected.to match_array certificates }
    end

    context 'with additional code' do
      before { additional_code }

      it { is_expected.to match_array [additional_code] }
    end

    context 'with certificates and additional code' do
      before { certificates && additional_code }

      it { is_expected.to match_array certificates << additional_code }
    end

    context 'with neither' do
      it { is_expected.to be_empty }
    end
  end
end
