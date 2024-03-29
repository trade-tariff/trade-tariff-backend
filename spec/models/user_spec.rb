require 'gds-sso/lint/user_spec'

RSpec.describe User do
  describe 'gds-sso' do
    it_behaves_like 'a gds-sso user class'
  end

  describe '#update_attributes' do
    let!(:user) { create :user }
    let(:attrs) do
      attributes_for :user
    end

    before do
      user.update(attrs)
      user.reload
    end

    it 'updates attributes', :aggregate_failures do
      expect(user.name).to eq(attrs[:name])
      expect(user.email).to eq(attrs[:email])
    end
  end

  describe '#create!' do
    describe 'valid' do
      let(:attrs) do
        attributes_for :user
      end

      it 'creates user', :aggregate_failures do
        expect {
          described_class.create!(attrs)
        }.to change(described_class, :count).by(1)
      end
    end

    describe 'invalid' do
      let!(:user) { create :user }
      let(:attrs) do
        attributes_for(:user).merge(
          id: user.id,
        )
      end

      it 'raises error', :aggregate_failures do
        expect {
          described_class.create!(attrs)
        }.to raise_error(Sequel::Error)
      end
    end
  end
end
