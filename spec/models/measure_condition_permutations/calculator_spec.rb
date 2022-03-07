RSpec.describe MeasureConditionPermutations::Calculator do
  subject(:calculator) { described_class.new measure }

  let(:measure) do
    create(:measure)
      .tap { |m| create :measure_condition, measure_sid: m.measure_sid }
      .reload
  end

  describe '#permuation_groups' do
    subject(:groups) { calculator.permutation_groups }

    let(:condition_codes) { measure.measure_conditions.map(&:condition_code).uniq }

    it { is_expected.to all be_instance_of MeasureConditionPermutations::Group }
    it { is_expected.to have_attributes length: condition_codes.length }

    context 'with conditions which do not match across condition groups' do
      let(:second_condition) { create :measure_condition, measure_sid: measure.measure_sid }
      let(:calculator) { described_class.new second_condition.measure.reload }

      it { is_expected.to have_attributes length: 2 }
      it { is_expected.to all have_attributes length: 1 }
    end

    context 'with conditions which match across condition groups' do
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

    context 'with mixture of conditions' do
      let(:first_condition) { measure.measure_conditions.first }

      let :second_condition do
        create :measure_condition, measure_sid: measure.measure_sid,
                                   certificate_type_code: first_condition.certificate_type_code,
                                   certificate_code: first_condition.certificate_code,
                                   condition_duty_amount: first_condition.condition_duty_amount
      end

      let :third_condition do
        create :measure_condition, measure_sid: second_condition.measure_sid,
                                   condition_code: first_condition.condition_code
      end

      let :fourth_condition do
        create :measure_condition, measure_sid: third_condition.measure_sid,
                                   condition_code: second_condition.condition_code
      end

      let :fifth_condition do
        create :measure_condition, measure_sid: fourth_condition.measure_sid,
                                   condition_code: fourth_condition.condition_code
      end

      let :calculator do
        described_class.new fifth_condition.measure.reload
      end

      it { is_expected.to have_attributes length: 1 }
      it { expect(groups.first.permutations.length).to be 3 }
      it { expect(groups.first.permutations.first.length).to be 1 }
      it { expect(groups.first.permutations.second.length).to be 2 }
      it { expect(groups.first.permutations.third.length).to be 2 }
    end
  end
end
