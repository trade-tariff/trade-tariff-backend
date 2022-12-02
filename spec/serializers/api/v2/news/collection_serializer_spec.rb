RSpec.describe Api::V2::News::CollectionSerializer do
  subject { described_class.new(collection).serializable_hash }

  let :collection do
    create :news_collection, :with_description, name: 'Serialized',
                                                slug: 'serialized'
  end

  describe '#serializable_hash' do
    let :expected do
      {
        data: {
          id: collection.id.to_s,
          type: :news_collection,
          attributes: {
            name: 'Serialized',
            slug: 'serialized',
            description: collection.description,
            priority: 0,
          },
        },
      }
    end

    it { is_expected.to eq expected }
  end
end
