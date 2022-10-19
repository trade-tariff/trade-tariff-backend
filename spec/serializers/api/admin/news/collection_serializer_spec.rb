RSpec.describe Api::Admin::News::CollectionSerializer do
  subject { described_class.new(collection).serializable_hash }

  let(:collection) { create :news_collection, name: 'Serialized' }

  describe '#serializable_hash' do
    let :expected do
      {
        data: {
          id: collection.id.to_s,
          type: :news_collection,
          attributes: {
            name: 'Serialized',
            created_at: collection.created_at,
            updated_at: collection.updated_at,
          },
        },
      }
    end

    it { is_expected.to eq expected }
  end
end
