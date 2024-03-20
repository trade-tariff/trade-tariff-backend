RSpec.describe GreenLanes::PermutationCalculatorService do
  subject(:permutations) { described_class.new(measures).call }

  describe '.call' do
    let(:measures) { create_list :measure, 1 }
    let(:measure) { create :measure, :with_measure_type, :with_base_regulation }

    shared_examples 'two segregated lists' do
      it { is_expected.to have_attributes length: 2 }
      it { expect(permutations[0]).to eq_pk [measures[0]] }
      it { expect(permutations[1]).to eq_pk [measures[1]] }
    end

    context 'with unrelated measures' do
      let(:measures) { create_list :measure, 3 }

      it { is_expected.to eq(measures.map { |m| [m] }) }
    end

    context 'with mixture of related and unrelated' do
      let :measures do
        measures = create_list(:measure, 2, :with_measure_type, :with_base_regulation)
        measures + create_list(
          :measure, 1,
          geographical_area_id: measures[0].geographical_area_id,
          measure_type_id: measures[0].measure_type_id,
          measure_generating_regulation_id: measures[0].measure_generating_regulation_id,
          measure_generating_regulation_role: measures[0].measure_generating_regulation_role
        )
      end

      it { is_expected.to have_attributes length: 2 }
      it { expect(permutations[0]).to eq_pk [measures[0], measures[2]] }
      it { expect(permutations[1]).to eq_pk [measures[1]] }
    end

    context 'with different regulation_id' do
      let :measures do
        [
          measure,
          create(:measure, :with_base_regulation,
                 measure_type_id: measure.measure_type_id,
                 geographical_area_id: measure.geographical_area_id),
        ]
      end

      it_behaves_like 'two segregated lists'
    end

    context 'with different regulation_role' do
      let :measures do
        [
          measure,
          create(:measure,
                 measure_generating_regulation_id: measure.measure_generating_regulation_id,
                 measure_generating_regulation_role: 4,
                 measure_type_id: measure.measure_type_id,
                 geographical_area_id: measure.geographical_area_id),
        ]
      end

      it_behaves_like 'two segregated lists'
    end

    context 'with different additional codes' do
      let :measures do
        [
          measure,
          create(:measure, :with_additional_code,
                 generating_regulation: measure.generating_regulation,
                 measure_type_id: measure.measure_type_id,
                 geographical_area_id: measure.geographical_area_id),
        ]
      end

      it_behaves_like 'two segregated lists'
    end

    context 'with different certificates' do
      let :measures do
        [
          measure,
          create(:measure, :with_measure_conditions,
                 generating_regulation: measure.generating_regulation,
                 measure_type_id: measure.measure_type_id,
                 geographical_area_id: measure.geographical_area_id,
                 certificate_type_code: 'Y',
                 certificate_code: '123'),
        ]
      end

      it_behaves_like 'two segregated lists'
    end

    context 'with different geographical area' do
      let :measures do
        [
          measure,
          create(:measure,
                 generating_regulation: measure.generating_regulation,
                 measure_type_id: measure.measure_type_id,
                 geographical_area_id: generate(:geographical_area_id)),
        ]
      end

      it_behaves_like 'two segregated lists'
    end

    context 'with different geographical area exclusions' do
      let :measures do
        [
          measure,
          create(:measure, :with_measure_excluded_geographical_area,
                 generating_regulation: measure.generating_regulation,
                 measure_type_id: measure.measure_type_id,
                 geographical_area_id: measure.geographical_area_id),
        ]
      end

      it_behaves_like 'two segregated lists'
    end
  end
end
