RSpec.describe Api::V2::GreenLanes::CategoryAssessmentPresenter do
  subject(:presented) { described_class.new(assessment, permutations.first, assessment.measures) }

  let(:assessment) { create :category_assessment, :with_measures, measures_count: 2 }

  let :permutations do
    GreenLanes::PermutationCalculatorService.new(assessment.measures).call
  end

  it { is_expected.to have_attributes id: /^[0-9a-f]{32}$/ }
  it { is_expected.to have_attributes category_assessment_id: assessment.id }
  it { is_expected.to have_attributes measure_ids: assessment.measures.map(&:measure_sid) }
  it { is_expected.to have_attributes theme_id: /\d+\.\d+/ }

  describe '.wrap' do
    subject(:wrapped) { described_class.wrap [assessment] }

    it { is_expected.to have_attributes length: 2 }
    it { is_expected.to all be_instance_of described_class }

    context 'with first presented category assessment' do
      subject { wrapped.first }

      it { is_expected.to have_attributes id: /^[0-9a-f]{32}$/ }
      it { is_expected.to have_attributes measure_ids: [assessment.measures.map(&:measure_sid).first] }
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

  describe '#certificates' do
    subject { presented.certificates }

    context 'with single certificates' do
      before do
        create :measure_condition, measure: assessment.measures.first, certificate:
      end

      context 'with exemption certificate' do
        let(:certificate) { create :certificate, :exemption }

        it { is_expected.to include certificate }
      end

      context 'with exemption certificate and overridden' do
        let(:certificate) { create :certificate, :exemption, exempting_certificate_override: true }

        it { is_expected.not_to include certificate }
      end

      context 'with licence certificate' do
        let(:certificate) { create :certificate, :licence }

        it { is_expected.not_to include certificate }
      end

      context 'with licence certificate and overridden' do
        let(:certificate) { create :certificate, :licence, exempting_certificate_override: true }

        it { is_expected.to include certificate }
      end
    end

    context 'with multiple certificates' do
      let(:certificate) { create :certificate, :exemption }
      let(:measure_sid) { assessment.measures.first.measure_sid }

      before do
        create(:measure_condition, measure_sid:,
                                   certificate:,
                                   condition_code: 'AB')

        create(:measure_condition, measure_sid:,
                                   certificate:,
                                   condition_code: 'CD')
      end

      context 'with singular exemptions' do
        it { is_expected.to include certificate }
      end

      context 'with combined exemptions' do
        before do
          create(:measure_condition, measure_sid:,
                                     certificate:,
                                     condition_code: 'AB',
                                     certificate_type_code: 'f',
                                     certificate_code: 'def',
                                     condition_duty_amount: 30_000)

          create(:measure_condition, measure_sid:,
                                     certificate:,
                                     condition_code: 'CD',
                                     certificate_type_code: 'f',
                                     certificate_code: 'def',
                                     condition_duty_amount: 30_000)
          Measure.refresh!
        end

        it { is_expected.to be_empty }
      end
    end
  end

  describe '#exemptions' do
    subject { presented.exemptions }

    let :certificates do
      create_pair(:certificate, :exemption).each do |certificate|
        create :measure_condition,
               measure: assessment.measures.first,
               certificate:
      end
    end

    let :exempting_additional_codes do
      additional_codes = create_list(:additional_code, 2, :with_exempting_additional_code_override)
      assessment.measures[0].update additional_code: additional_codes[0]
      assessment.measures[1].update additional_code: additional_codes[1]
      additional_codes
    end

    let :additional_codes do
      additional_codes = create_list(:additional_code, 2)
      assessment.measures[0].update additional_code: additional_codes[0]
      assessment.measures[1].update additional_code: additional_codes[1]
      additional_codes
    end

    context 'with certificates' do
      before { certificates }

      it { is_expected.to match_array certificates }
    end

    context 'with duplicate conditions pointing to same certificate' do
      before { certificates }

      let(:measure) { assessment.measures.first }

      let :certificates do
        create_list(:certificate, 1, :exemption).each do |certificate|
          create(:measure_condition, measure:, certificate:)
          create(:measure_condition, measure:, certificate:)
        end
      end

      it { is_expected.to eq_pk certificates }
    end

    context 'with white listed additional code' do
      before { exempting_additional_codes }

      it { is_expected.to match_array exempting_additional_codes }
    end

    context 'with additional code without white listed' do
      before { additional_codes }

      it { is_expected.to match_array [] }
    end

    context 'with certificates and additional code' do
      before { certificates && exempting_additional_codes }

      it { is_expected.to match_array certificates + exempting_additional_codes }
    end

    context 'with pseudo exemption' do
      before { assessment.add_exemption create(:green_lanes_exemption) }

      it { is_expected.to include instance_of Api::V2::GreenLanes::ExemptionPresenter }
    end

    context 'with no exemptions' do
      it { is_expected.to be_empty }
    end
  end
end
