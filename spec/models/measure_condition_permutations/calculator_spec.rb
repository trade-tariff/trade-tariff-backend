RSpec.describe MeasureConditionPermutations::Calculator do
  subject(:calculator) { described_class.new(measure) }

  let(:measure) do
    create(:measure)
      .tap { |m| create :measure_condition, measure_sid: m.measure_sid }
  end

  describe 'filtering measure_conditions' do
    # rubocop:disable RSpec/LetSetup
    subject :measure_conditions do
      calculator.permutation_groups
                .flat_map(&:permutations)
                .flat_map(&:measure_conditions)
    end

    shared_examples 'an included measure condition' do
      it { expect(measure_conditions).to include(measure_condition) }
    end

    shared_examples_for 'an excluded measure condition' do
      it { expect(measure_conditions).not_to include(measure_condition) }
    end

    it_behaves_like 'an included measure condition' do
      let!(:measure_condition) { measure.measure_conditions.first }
    end

    it_behaves_like 'an included measure condition' do
      let!(:measure_condition) do
        create(
          :measure_condition,
          :negative,
          measure_sid: measure.measure_sid,
          action_code: '08',
        )
      end
    end

    it_behaves_like 'an included measure condition' do
      let!(:measure_condition) do
        create(
          :measure_condition,
          :negative,
          :threshold,
          measure_sid: measure.measure_sid,
        )
      end
    end

    it_behaves_like 'an included measure condition' do
      let!(:measure_condition) do
        create(
          :measure_condition,
          :negative,
          :document,
          measure_sid: measure.measure_sid,
        )
      end
    end

    it_behaves_like 'an excluded measure condition' do
      let!(:measure_condition) do
        create(
          :measure_condition,
          :negative,
          measure_sid: measure.measure_sid,
        )
      end
    end

    it_behaves_like 'an excluded measure condition' do
      let!(:measure_condition) do
        create(
          :measure_condition,
          :cds_waiver,
          measure_sid: measure.measure_sid,
        )
      end
    end

    it_behaves_like 'an excluded measure condition' do
      let!(:measure_condition) do
        create(
          :measure_condition,
          :negative,
          measure_sid: measure.measure_sid,
        )
      end
    end
    # rubocop:enable RSpec/LetSetup
  end

  describe '#permutation_groups' do
    subject(:groups) { calculator.permutation_groups }

    context 'with conditions which do not match across condition groups' do
      let(:second_condition) { create :measure_condition, measure_sid: measure.measure_sid }
      let(:calculator) { described_class.new second_condition.measure.reload }

      it 'generates multiple groups' do
        expect(groups).to have_attributes length: 2
      end

      it 'has one permutation per group' do
        expect(groups).to all have_attributes length: 1
      end
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

      it 'has a single group' do
        expect(groups).to have_attributes length: 1
      end

      it 'with a single permutation' do
        expect(groups).to all have_attributes length: 1
      end

      it 'combines the conditions within the permutation' do
        expect(groups.first.permutations.first.length).to be 1
      end
    end
  end
end
