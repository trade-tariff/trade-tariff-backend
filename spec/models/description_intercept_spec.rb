RSpec.describe DescriptionIntercept do
  describe 'validations' do
    subject(:intercept) { build(:description_intercept, **attrs) }

    let(:attrs) { {} }

    it 'is valid with the factory defaults' do
      expect(intercept).to be_valid
    end

    context 'when term is blank' do
      let(:attrs) { { term: nil } }

      it 'is invalid' do
        expect(intercept).not_to be_valid
        expect(intercept.errors[:term]).to be_present
      end
    end

    context 'when sources is blank' do
      let(:attrs) { { sources: [] } }

      it 'is invalid' do
        expect(intercept).not_to be_valid
        expect(intercept.errors[:sources]).to be_present
      end
    end
  end

  describe 'versioning' do
    it 'creates versions on create and update' do
      intercept = create(:description_intercept)

      expect {
        intercept.update(message: 'Updated markdown')
      }.to change { Version.where(item_type: 'DescriptionIntercept', item_id: intercept.id.to_s).count }.by(1)

      expect(Version.where(item_type: 'DescriptionIntercept', item_id: intercept.id.to_s).count).to eq(2)
    end
  end
end
