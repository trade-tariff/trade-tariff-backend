RSpec.describe Api::V2::News::CollectionSerializer do
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
          },
        },
      }
    end

    it { is_expected.to eq expected }
  end
end
