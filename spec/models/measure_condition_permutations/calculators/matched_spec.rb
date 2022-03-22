RSpec.describe MeasureConditionPermutations::Calculators::Matched do
  subject :calculator do
    described_class.new measure_with_conditions.measure_sid,
                        measure_with_conditions.measure_conditions
  end

  let(:measure) { create(:measure) }

  describe '#permutation_groups' do
    subject(:groups) { calculator.permutation_groups }

    describe 'matching' do
      context 'when all conditions match' do
        let(:measure_with_conditions) { second.measure.reload }
        let(:first) { create :measure_condition, measure_sid: measure.measure_sid }

        let :second do
          create :measure_condition,
                 measure_sid: measure.measure_sid,
                 certificate_type_code: first.certificate_type_code,
                 certificate_code: first.certificate_code,
                 condition_duty_amount: first.condition_duty_amount
        end

        it 'has one group' do
          expect(groups).to have_attributes length: 1
        end

        it 'has one permutation within the group' do
          expect(groups).to all have_attributes length: 1
        end

        it 'has one condition id in that permutation' do
          expect(groups.first.permutations.first.length).to be 1
        end
      end

      context 'when only some conditions match' do
        let(:measure_with_conditions) { conditions.first.measure.reload }

        let :conditions do
          [
            create(:measure_condition, measure_sid: measure.measure_sid,
                                       condition_code: 'AB',
                                       certificate_type_code: 'f',
                                       certificate_code: 'def',
                                       condition_duty_amount: 30_000),

            create(:measure_condition, measure_sid: measure.measure_sid,
                                       condition_code: 'CD',
                                       certificate_type_code: 'f',
                                       certificate_code: 'def',
                                       condition_duty_amount: 30_000),

            create(:measure_condition, measure_sid: measure.measure_sid,
                                       condition_code: 'AB'),

            create(:measure_condition, measure_sid: measure.measure_sid,
                                       condition_code: 'CD'),

            create(:measure_condition, measure_sid: measure.measure_sid,
                                       condition_code: 'CD'),
          ]
        end

        it 'creates a single group' do
          expect(groups).to have_attributes length: 1
        end

        describe 'the groups permutations' do
          subject(:condition_id_permutations) do
            groups.first.permutations.map(&:measure_condition_ids)
          end

          it 'has 3 permutations' do
            expect(condition_id_permutations).to have_attributes length: 3
          end

          it 'contains a permutation with the matched conditions' do
            expect(condition_id_permutations.first).to eql [
              conditions.first.measure_condition_sid,
            ]
          end

          it 'contains a permutation with the first combination of unmatched conditions' do
            expect(condition_id_permutations).to include [
              conditions.third.measure_condition_sid,
              conditions.fourth.measure_condition_sid,
            ]
          end

          it 'contains a permutation with the other combination of unmatched conditions' do
            expect(condition_id_permutations).to include [
              conditions.third.measure_condition_sid,
              conditions.fifth.measure_condition_sid,
            ]
          end
        end
      end
    end

    describe 'sorting' do
      subject(:permutations) { calculator.permutation_groups.first.permutations }

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
end
