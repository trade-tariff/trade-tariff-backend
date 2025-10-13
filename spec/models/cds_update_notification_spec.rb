RSpec.describe CdsUpdateNotification do
  describe 'validations' do
    context 'with correct info' do
      let(:notification) { build :cds_update_notification }

      it 'is a valid entity' do
        expect(notification).to be_valid
      end
    end

    context 'with incorrect date provided' do
      let(:notification) { build :cds_update_notification, filename: nil }

      it 'is not a valid entity' do
        expect(notification).not_to be_valid
      end
    end
  end
end
