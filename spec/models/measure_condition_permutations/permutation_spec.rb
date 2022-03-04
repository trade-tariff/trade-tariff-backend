RSpec.describe MeasureConditionPermutations::Permutation do
  subject(:permutation) { described_class.new conditions }

  let(:measure) { create :measure, :with_measure_conditions }
  let(:conditions) { measure.measure_conditions.to_a }

  it { is_expected.to be_instance_of described_class }
  it { is_expected.to respond_to :id }
  it { is_expected.to respond_to :measure_conditions }
  it { is_expected.to respond_to :measure_condition_ids }
  it { is_expected.to have_attributes length: 1 }

  describe '#initialize' do
    context 'with multiple conditions' do
      it { is_expected.to have_attributes length: 1 }
    end

    context 'with single condition' do
      let(:conditions) { measure.measure_conditions.first }

      it { is_expected.to have_attributes length: 1 }
    end
  end

  describe '#id' do
    subject { permutation.id }

    it { is_expected.to match %r{\A[0-9a-f]{32}\z} }

    context 'when conditions are updated' do
      let :conditions do
        measure.measure_conditions.to_a + measure.measure_conditions.to_a
      end

      it 'will change' do
        expect { permutation.remove_duplicate_conditions }.to \
          change permutation, :id
      end
    end
  end

  describe '#remove_duplicate_conditions' do
    subject do
      described_class.new(duplicated_conditions)
                     .remove_duplicate_conditions
                     .measure_conditions
    end

    let(:duplicated_conditions) { conditions + conditions }

    it { is_expected.to eql conditions }
  end

  describe '#measure_condition_ids' do
    subject { permutation.measure_condition_ids }

    it { is_expected.to have_attributes length: permutation.measure_conditions.length }
    it { is_expected.to all match be_instance_of Integer }
  end
end
