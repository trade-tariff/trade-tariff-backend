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

    context 'when using the new guidance and filtering fields' do
      let(:attrs) do
        {
          message: 'Consult the footwear guidance.',
          guidance_level: 'warning',
          guidance_location: 'results',
          escalate_to_webchat: true,
          filter_prefixes: Sequel.pg_array(%w[6403 6404], :text),
        }
      end

      it 'is valid' do
        expect(intercept).to be_valid
      end
    end

    context 'when excluded and filtering prefixes are both set' do
      let(:attrs) do
        {
          excluded: true,
          filter_prefixes: Sequel.pg_array(%w[6403], :text),
        }
      end

      it 'is invalid' do
        expect(intercept).not_to be_valid
        expect(intercept.errors[:filter_prefixes]).to include('cannot be set when excluded')
      end
    end

    context 'when guidance level is set without a message' do
      let(:attrs) do
        {
          message: nil,
          guidance_level: 'warning',
        }
      end

      it 'is invalid' do
        expect(intercept).not_to be_valid
        expect(intercept.errors[:guidance_level]).to include('requires message')
      end
    end

    context 'when guidance location is set without a message' do
      let(:attrs) do
        {
          message: nil,
          guidance_location: 'results',
        }
      end

      it 'is invalid' do
        expect(intercept).not_to be_valid
        expect(intercept.errors[:guidance_location]).to include('requires message')
      end
    end

    context 'when a filtering prefix is blank' do
      let(:attrs) do
        {
          filter_prefixes: Sequel.pg_array(['6403', ''], :text),
        }
      end

      it 'is invalid' do
        expect(intercept).not_to be_valid
        expect(intercept.errors[:filter_prefixes]).to include('cannot contain blank prefixes')
      end
    end

    context 'when a filtering prefix is not numeric' do
      let(:attrs) do
        {
          filter_prefixes: Sequel.pg_array(%w[64A3], :text),
        }
      end

      it 'is invalid' do
        expect(intercept).not_to be_valid
        expect(intercept.errors[:filter_prefixes]).to include('must contain only numeric prefixes')
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
