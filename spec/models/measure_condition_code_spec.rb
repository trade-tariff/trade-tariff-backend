RSpec.describe MeasureConditionCode do
  describe '#requirement_operator' do
    shared_examples 'a measure condition requirement operator' do |condition_code, expected_operator|
      subject(:requirement_operator) { build(:measure_condition_code, condition_code:).requirement_operator }

      it { is_expected.to eq(expected_operator) }
    end

    it_behaves_like 'a measure condition requirement operator', 'E', '=<'
    it_behaves_like 'a measure condition requirement operator', 'F', '=>'
    it_behaves_like 'a measure condition requirement operator', 'G', '=>'
    it_behaves_like 'a measure condition requirement operator', 'I', '=<'
    it_behaves_like 'a measure condition requirement operator', 'J', '>'
    it_behaves_like 'a measure condition requirement operator', 'L', '>'
    it_behaves_like 'a measure condition requirement operator', 'M', '=>'
    it_behaves_like 'a measure condition requirement operator', 'N', '=>'
    it_behaves_like 'a measure condition requirement operator', 'O', '>'
    it_behaves_like 'a measure condition requirement operator', 'R', '=>'
    it_behaves_like 'a measure condition requirement operator', 'U', '>'
    it_behaves_like 'a measure condition requirement operator', 'V', '=>'
    it_behaves_like 'a measure condition requirement operator', 'X', '>'
    it_behaves_like 'a measure condition requirement operator', 'FOO', nil
    it_behaves_like 'a measure condition requirement operator', nil, nil
  end
end
