RSpec.describe PublicUsers::UserPreference do
  describe 'attributes' do
    it { is_expected.to respond_to :user_id }
    it { is_expected.to respond_to :chapter_ids }
  end

  describe 'validations' do
    subject(:errors) { instance.tap(&:valid?).errors }

    let(:instance) { described_class.new }

    it { is_expected.to include user_id: ['is not present'] }

    context 'with duplicate entry' do
      let(:user) { create(:public_users_user) }
      let(:chapter_ids) { '01 02' }

      before do
        create(:public_users_user_preference, user_id: user.id, chapter_ids: chapter_ids)
      end

      it 'fails validation' do
        duplicate = build(:public_users_user_preference, user_id: user.id, chapter_ids: chapter_ids)
        expect(duplicate.valid?).to be false
      end
    end
  end
end
