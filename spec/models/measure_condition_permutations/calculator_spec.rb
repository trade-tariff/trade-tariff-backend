RSpec.describe MeasureConditionPermutations::Calculator do
  subject(:calculator) { described_class.new measure_with_conditions }

  let(:measure) do
    create(:measure)
      .tap { |m| create :measure_condition, measure_sid: m.measure_sid }
  end

  describe '#measure_conditions' do
    subject { calculator.measure_conditions }

    context 'for regular condition' do
      let(:measure_with_conditions) { measure.reload }
      let(:first_condition) { measure.measure_conditions.first }

      it { is_expected.to include(first_condition) }
    end

    context 'with universal waiver conditions do' do
      let :waiver_condition do
        create :measure_condition, :cds_waiver, measure_sid: measure.measure_sid
      end

      let(:measure_with_conditions) { waiver_condition.measure.reload }

      it { is_expected.not_to include(waiver_condition) }
    end

    context 'with negative action conditions do' do
      let :negative_condition do
        create :measure_condition, :negative, measure_sid: measure.measure_sid
      end

      let(:measure_with_conditions) { negative_condition.measure.reload }

      it { is_expected.not_to include(negative_condition) }
    end
  end

  describe '#permuation_groups' do
    subject(:groups) { calculator.permutation_groups }

    context 'with conditions which do not match across condition groups' do
      let(:second_condition) { create :measure_condition, measure_sid: measure.measure_sid }
      let(:calculator) { described_class.new second_condition.measure.reload }

      it { is_expected.to have_attributes length: 2 }
      it { is_expected.to all have_attributes length: 1 }
    end

    context 'with conditions which match across condition groups' do
      describe 'matching' do
        let(:first_condition) { measure.measure_conditions.first }

        let :second_condition do
          create :measure_condition, measure_sid: measure.measure_sid,
                                     certificate_type_code: first_condition.certificate_type_code,
                                     certificate_code: first_condition.certificate_code,
                                     condition_duty_amount: first_condition.condition_duty_amount
        end

        let(:calculator) { described_class.new second_condition.measure.reload }

        it { is_expected.to have_attributes length: 1 }
        it { is_expected.to all have_attributes length: 1 }
        it { expect(groups.first.permutations.first.length).to be 1 }
      end

      describe 'sorting' do
        subject(:permutations) { groups.first.permutations }

        let :measure_with_conditions do
          measure = create(:measure)

          threshold = create :measure_condition, :threshold, measure_sid: measure.measure_sid
          create :measure_condition, :threshold, measure_sid: measure.measure_sid,
                                                 condition_duty_amount: threshold.condition_duty_amount

          exemption = create :measure_condition, :exemption, measure_sid: measure.measure_sid
          create :measure_condition, :exemption, measure_sid: measure.measure_sid,
                                                 certificate_type_code: exemption.certificate_type_code,
                                                 certificate_code: exemption.certificate_code

          document = create :measure_condition, :document, measure_sid: measure.measure_sid
          create :measure_condition, :document, measure_sid: measure.measure_sid,
                                                certificate_type_code: document.certificate_type_code,
                                                certificate_code: document.certificate_code

          measure.reload
        end

        it { is_expected.to have_attributes length: 3 }

        it { expect(permutations[0].measure_conditions).to all have_attributes measure_condition_class: 'document' }
        it { expect(permutations[1].measure_conditions).to all have_attributes measure_condition_class: 'exemption' }
        it { expect(permutations[2].measure_conditions).to all have_attributes measure_condition_class: 'threshold' }
      end
    end

    context 'with mixture of conditions' do
      let :measure_with_conditions do
        create(:measure).tap do |measure|
          first = create :measure_condition, measure_sid: measure.measure_sid

          second = create :measure_condition, measure_sid: measure.measure_sid,
                                              certificate_type_code: first.certificate_type_code,
                                              certificate_code: first.certificate_code,
                                              condition_duty_amount: first.condition_duty_amount

          create :measure_condition, measure_sid: measure.measure_sid,
                                     condition_code: first.condition_code

          create :measure_condition, measure_sid: measure.measure_sid,
                                     condition_code: second.condition_code

          create :measure_condition, measure_sid: measure.measure_sid,
                                     condition_code: second.condition_code
        end
      end

      it { is_expected.to have_attributes length: 1 }
      it { expect(groups.first.permutations.length).to be 3 }
      it { expect(groups.first.permutations.first.length).to be 1 }
      it { expect(groups.first.permutations.second.length).to be 2 }
      it { expect(groups.first.permutations.third.length).to be 2 }
    end
  end
end
