RSpec.describe DutyExpressionDescription do
  describe '#abbreviation' do
    context 'abbreviation present for duty expression id' do
      let(:duty_expression_description) { build :duty_expression_description, duty_expression_id: '37' }

      it 'returns the abbreviation' do
        expect(duty_expression_description.abbreviation).to eq 'NIHIL'
      end
    end

    context 'abbreviation missing for duty expression id' do
      let(:duty_expression_description) { build :duty_expression_description, duty_expression_id: 'ER' }

      it 'is blank' do
        expect(duty_expression_description.abbreviation).to be_blank
      end
    end
  end
end
