RSpec.describe MeasureConditionPermutations::GreenLanesCalculator do
  let(:calculator) { described_class.new(anything, certificates_in, measure_sid) }
  let(:measure_sid) { 123 }

  shared_examples 'returns a wrapped CertificatePresenter' do
    it 'returns a wrapped CertificatePresenter' do
      expect(Api::V2::GreenLanes::CertificatePresenter).to receive(:wrap).with(certificates_out, measure_sid, group_mapping)
      calculator.group_certificates
    end
  end

  describe '#group_certificates' do
    context 'when there is one group and one permutation' do
      let(:certificates_out) { [double('Certificate', id: 1), double('Certificate', id: 2)] }
      let(:certificates_in) { certificates_out }
      let(:group_mapping) { { 1 => [0], 2 => [0] } }

      before do
        allow(calculator).to receive(:condition_permutation_groups)
                               .and_return([
                                             double('PermutationGroup', permutations: [
                                               double('Permutation', measure_conditions: [
                                                 double('Condition', certificate: double('Certificate', id: 1)),
                                                 double('Condition', certificate: double('Certificate', id: 2))
                                               ])
                                             ])
                                           ])

      end

      it_behaves_like 'returns a wrapped CertificatePresenter'
    end

    context 'when there is one group and multiple permutation' do
      let(:certificates_out) { [double('Certificate', id: 1), double('Certificate', id: 2),
                                double('Certificate', id: 3), double('Certificate', id: 4)] }
      let(:certificates_in) { certificates_out }
      let(:group_mapping) { { 1 => [0], 2 => [0], 3 => [1], 4 => [1] } }

      before do
        allow(calculator).to receive(:condition_permutation_groups)
                               .and_return([
                                             double('PermutationGroup', permutations: [
                                               double('Permutation', measure_conditions: [
                                                 double('Condition', certificate: double('Certificate', id: 1)),
                                                 double('Condition', certificate: double('Certificate', id: 2))
                                               ]),
                                               double('Permutation', measure_conditions: [
                                                 double('Condition', certificate: double('Certificate', id: 3)),
                                                 double('Condition', certificate: double('Certificate', id: 4))
                                               ])
                                             ])
                                           ])

      end

      it_behaves_like 'returns a wrapped CertificatePresenter'
    end

    context 'when there is one group and multiple permutation it filter out uncompleted group' do
      let(:certificates_out) { [double('Certificate', id: 1), double('Certificate', id: 2)] }
      let(:certificates_in) { certificates_out + [double('Certificate', id: 3)] }
      let(:group_mapping) { { 1 => [0], 2 => [0] } }

      before do
        allow(calculator).to receive(:condition_permutation_groups)
                               .and_return([
                                             double('PermutationGroup', permutations: [
                                               double('Permutation', measure_conditions: [
                                                 double('Condition', certificate: double('Certificate', id: 1)),
                                                 double('Condition', certificate: double('Certificate', id: 2))
                                               ]),
                                               double('Permutation', measure_conditions: [
                                                 double('Condition', certificate: double('Certificate', id: 3)),
                                                 double('Condition', certificate: double('Certificate', id: 4))
                                               ])
                                             ])
                                           ])

      end

      it_behaves_like 'returns a wrapped CertificatePresenter'
    end

    context 'when there is one group and multiple permutation with one certificate in multiple permutation' do
      let(:certificates_out) { [double('Certificate', id: 1), double('Certificate', id: 2), double('Certificate', id: 3)] }
      let(:certificates_in) { certificates_out }
      let(:group_mapping) { { 1 => [0], 2 => [0, 1], 3 => [1] } }

      before do
        allow(calculator).to receive(:condition_permutation_groups)
                               .and_return([
                                             double('PermutationGroup', permutations: [
                                               double('Permutation', measure_conditions: [
                                                 double('Condition', certificate: double('Certificate', id: 1)),
                                                 double('Condition', certificate: double('Certificate', id: 2))
                                               ]),
                                               double('Permutation', measure_conditions: [
                                                 double('Condition', certificate: double('Certificate', id: 2)),
                                                 double('Condition', certificate: double('Certificate', id: 3))
                                               ])
                                             ])
                                           ])

      end

      it_behaves_like 'returns a wrapped CertificatePresenter'
    end

    context 'when there is one group and multiple permutation with one certificate in multiple permutation, but that permutation is removed' do
      let(:certificates_out) { [double('Certificate', id: 1), double('Certificate', id: 2)] }
      let(:certificates_in) { certificates_out + [double('Certificate', id: 3)] }
      let(:group_mapping) { { 1 => [0], 2 => [0] } }

      before do
        allow(calculator).to receive(:condition_permutation_groups)
                               .and_return([
                                             double('PermutationGroup', permutations: [
                                               double('Permutation', measure_conditions: [
                                                 double('Condition', certificate: double('Certificate', id: 1)),
                                                 double('Condition', certificate: double('Certificate', id: 2))
                                               ]),
                                               double('Permutation', measure_conditions: [
                                                 double('Condition', certificate: double('Certificate', id: 2)),
                                                 double('Condition', certificate: double('Certificate', id: 3)),
                                                 double('Condition', certificate: double('Certificate', id: 4))
                                               ])
                                             ])
                                           ])

      end

      it_behaves_like 'returns a wrapped CertificatePresenter'
    end

    context 'when there is one group with individual certificate' do
      let(:certificates_out) { [double('Certificate', id: 1), double('Certificate', id: 2), double('Certificate', id: 3)] }
      let(:certificates_in) { certificates_out }
      let(:group_mapping) { { 1 => [0], 2 => [1], 3 => [2] } }

      before do
        allow(calculator).to receive(:condition_permutation_groups)
                               .and_return([
                                             double('PermutationGroup', permutations: [
                                               double('Permutation', measure_conditions: [
                                                 double('Condition', certificate: double('Certificate', id: 1)),
                                               ]),
                                               double('Permutation', measure_conditions: [
                                                 double('Condition', certificate: double('Certificate', id: 2)),
                                               ]),
                                               double('Permutation', measure_conditions: [
                                                 double('Condition', certificate: double('Certificate', id: 3)),
                                               ])
                                             ])
                                           ])

      end

      it_behaves_like 'returns a wrapped CertificatePresenter'
    end

    context 'when there are multiple groups' do
      let(:certificates_out) { [double('Certificate', id: 1), double('Certificate', id: 2), double('Certificate', id: 3),
                                double('Certificate', id: 4), double('Certificate', id: 5)] }
      let(:certificates_in) { certificates_out }
      let(:group_mapping) { { 1 => [0], 2 => [1], 3 => [1], 4 => [2], 5 => [2] } }

      before do
        allow(calculator).to receive(:condition_permutation_groups)
                               .and_return([
                                             double('PermutationGroup', permutations: [
                                               double('Permutation', measure_conditions: [
                                                 double('Condition', certificate: double('Certificate', id: 1)),
                                               ]),
                                               double('Permutation', measure_conditions: [
                                                 double('Condition', certificate: double('Certificate', id: 2)),
                                                 double('Condition', certificate: double('Certificate', id: 3)),
                                               ]),
                                             ]),
                                             double('PermutationGroup', permutations: [
                                               double('Permutation', measure_conditions: [
                                                 double('Condition', certificate: double('Certificate', id: 4)),
                                                 double('Condition', certificate: double('Certificate', id: 5)),
                                               ]),
                                             ])
                                           ])

      end

      it_behaves_like 'returns a wrapped CertificatePresenter'
    end

    context 'when there are multiple groups, it filters certificate in uncompleted group' do
      let(:certificates_out) { [double('Certificate', id: 1), double('Certificate', id: 2), double('Certificate', id: 3)] }
      let(:certificates_in) { certificates_out }
      let(:group_mapping) { { 1 => [0], 2 => [1], 3 => [1] } }

      before do
        allow(calculator).to receive(:condition_permutation_groups)
                               .and_return([
                                             double('PermutationGroup', permutations: [
                                               double('Permutation', measure_conditions: [
                                                 double('Condition', certificate: double('Certificate', id: 1)),
                                               ]),
                                               double('Permutation', measure_conditions: [
                                                 double('Condition', certificate: double('Certificate', id: 2)),
                                                 double('Condition', certificate: double('Certificate', id: 3)),
                                               ]),
                                             ]),
                                             double('PermutationGroup', permutations: [
                                               double('Permutation', measure_conditions: [
                                                 double('Condition', certificate: double('Certificate', id: 2)),
                                                 double('Condition', certificate: double('Certificate', id: 5)),
                                               ]),
                                             ])
                                           ])

      end

      it_behaves_like 'returns a wrapped CertificatePresenter'
    end

    context 'when there are multiple groups and certificate exist in multiple groups' do
      let(:certificates_out) { [double('Certificate', id: 1), double('Certificate', id: 2), double('Certificate', id: 3), double('Certificate', id: 4)] }
      let(:certificates_in) { certificates_out }
      let(:group_mapping) { { 1 => [0], 2 => [1, 2], 3 => [1], 4 => [2] } }

      before do
        allow(calculator).to receive(:condition_permutation_groups)
                               .and_return([
                                             double('PermutationGroup', permutations: [
                                               double('Permutation', measure_conditions: [
                                                 double('Condition', certificate: double('Certificate', id: 1)),
                                               ]),
                                               double('Permutation', measure_conditions: [
                                                 double('Condition', certificate: double('Certificate', id: 2)),
                                                 double('Condition', certificate: double('Certificate', id: 3)),
                                               ]),
                                             ]),
                                             double('PermutationGroup', permutations: [
                                               double('Permutation', measure_conditions: [
                                                 double('Condition', certificate: double('Certificate', id: 2)),
                                                 double('Condition', certificate: double('Certificate', id: 4)),
                                               ]),
                                             ])
                                           ])

      end

      it_behaves_like 'returns a wrapped CertificatePresenter'
    end
  end
end
