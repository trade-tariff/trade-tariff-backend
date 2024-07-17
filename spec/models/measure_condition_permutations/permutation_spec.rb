RSpec.describe MeasureConditionPermutations::Permutation do
  subject(:permutation) { described_class.new conditions }

  let(:measure) do
    create(:measure)
      .tap { |m| create_list(:measure_condition, 2, measure_sid: m.measure_sid) }
      .reload
  end

  let(:conditions) { measure.measure_conditions.to_a }

  it { is_expected.to be_instance_of described_class }
  it { is_expected.to respond_to :id }
  it { is_expected.to respond_to :measure_conditions }
  it { is_expected.to respond_to :measure_condition_ids }
  it { is_expected.to have_attributes length: 2 }

  describe '#initialize' do
    context 'with multiple conditions' do
      it { is_expected.to have_attributes length: 2 }
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

      it 'changes' do
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

  describe '#==' do
    let(:other) { described_class.new conditions }

    it { is_expected.to eq other }

    context 'with different order conditions' do
      let(:other) { described_class.new conditions.reverse }

      it { is_expected.not_to eq other }
    end

    context 'with different permutation' do
      let :other_measure do
        create(:measure)
          .tap { |om| create_list(:measure_condition, 2, measure_sid: om.measure_sid) }
          .reload
      end

      let(:other) { described_class.new other_measure.measure_conditions }

      it { is_expected.not_to eq other }
    end
  end
end
