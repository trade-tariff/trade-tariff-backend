describe Rollback do
  describe 'validations' do
    context 'with correct info' do
      let(:rollback) { build :rollback }

      it 'is a valid entity' do
        expect(rollback).to be_valid
      end
    end

    context 'with incorrect date provided' do
      let(:rollback) { build :rollback, date: 'abc' }

      it 'is not a valid entity' do
        expect(rollback).not_to be_valid
      end
    end
  end
end
