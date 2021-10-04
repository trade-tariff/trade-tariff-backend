RSpec.describe DutyExpression do
  describe '#meursing_measure_type_id' do
    subject(:duty_expression) { build(:duty_expression, duty_expression_id: duty_expression_id) }

    shared_examples_for 'a meursing duty expression' do |duty_expression_id, expected_measure_type_id|
      let(:duty_expression_id) { duty_expression_id }

      it { expect(duty_expression.meursing_measure_type_id).to eq(expected_measure_type_id) }
    end

    it_behaves_like 'a meursing duty expression', '12', '674'
    it_behaves_like 'a meursing duty expression', '14', '674'
    it_behaves_like 'a meursing duty expression', '21', '672'
    it_behaves_like 'a meursing duty expression', '25', '672'
    it_behaves_like 'a meursing duty expression', '27', '673'
    it_behaves_like 'a meursing duty expression', '29', '673'
    it_behaves_like 'a meursing duty expression', 'foo', nil
  end
end
