RSpec.describe PublicUsers::DataExport do
  subject(:data_export) { described_class.new(user: user) }

  let(:user) { create(:public_user) }

  describe 'associations' do
    it 'has a user association' do
      association = described_class.association_reflections[:user]
      expect(association[:type]).to eq(:many_to_one)
    end
  end

  context 'when status is allowed' do
    PublicUsers::DataExport::ALLOWED_STATUSES.each do |valid_status|
      it "is valid for status '#{valid_status}'" do
        data_export.status = valid_status
        data_export.export_type = PublicUsers::DataExport::ALLOWED_EXPORT_TYPES.first
        data_export.valid?
        expect(data_export.errors).to be_empty
      end
    end
  end

  context 'when export type is allowed' do
    PublicUsers::DataExport::ALLOWED_EXPORT_TYPES.each do |valid_export_type|
      it "is valid for export_type '#{valid_export_type}'" do
        data_export.status = PublicUsers::DataExport::QUEUED
        data_export.export_type = valid_export_type
        data_export.valid?
        expect(data_export.errors).to be_empty
      end
    end
  end

  context 'when status is not allowed' do
    let(:invalid_status) { 'invalid_status' }

    it 'is not valid' do
      data_export.status = invalid_status
      data_export.valid?
      expect(data_export.errors[:status]).to eq(['is not valid'])
    end
  end
end
