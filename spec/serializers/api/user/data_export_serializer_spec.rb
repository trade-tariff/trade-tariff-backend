RSpec.describe Api::User::DataExportSerializer do
  subject(:serialized) { described_class.new(data_export).serializable_hash }

  let(:user) { create(:public_user) }

  let(:data_export) do
    create(
      :data_export,
      user: user,
      export_type: PublicUsers::DataExport::CCWL,
      status: PublicUsers::DataExport::COMPLETED,
      s3_key: 'data/export/2026/03/09/ccwl/1_test.xlsx',
      file_name: 'commodity_watch_list-your_codes_2026-03-09.xlsx',
    )
  end

  describe '#serializable_hash' do
    it 'matches the expected serialized structure' do
      expected = {
        data: {
          id: data_export.id.to_s,
          type: :data_export,
          attributes: {
            status: data_export.status,
            export_type: data_export.export_type,
            file_name: data_export.file_name,
            s3_key: data_export.s3_key,
            created_at: data_export.created_at,
            updated_at: data_export.updated_at,
          },
        },
      }
      expect(serialized).to eq(expected)
    end
  end
end
