RSpec.describe News::Collection do
  describe 'attributes' do
    it { is_expected.to respond_to :name }
    it { is_expected.to respond_to :slug }
    it { is_expected.to respond_to :priority }
    it { is_expected.to respond_to :description }
    it { is_expected.to respond_to :published }
    it { is_expected.to respond_to :created_at }
    it { is_expected.to respond_to :updated_at }
  end

  describe 'validations' do
    subject(:errors) { instance.tap(&:valid?).errors }

    let(:instance) { described_class.new }

    it { is_expected.to include(name: ['is not present']) }
    it { is_expected.to include(slug: ['is not present']) }

    context 'with blank attributes' do
      let(:instance) { described_class.new name: '', slug: '' }

      it { is_expected.to include(name: ['is not present']) }
      it { is_expected.to include(slug: ['is not present']) }
    end

    context 'with duplicated attributes' do
      before { create :news_collection, name: 'testing', slug: 'testing' }

      let(:instance) { described_class.new name: 'testing', slug: 'testing' }

      it { is_expected.to include(name: ['is already taken']) }
      it { is_expected.to include(slug: ['is already taken']) }
    end

    context 'with invalid format slug' do
      let(:instance) { described_class.new name: 'testing', slug: 'with space' }

      it { is_expected.to include(slug: ['is invalid']) }
    end
  end

  describe 'associations' do
    describe '#items' do
      subject { described_class.where(id: collection.id).take.items.pluck(:id) }

      before { items.reverse.each(&collection.method(:add_item)) }

      let(:collection) { create :news_collection }

      let :items do
        [
          create(:news_item, start_date: 5.days.ago),
          create(:news_item, start_date: 3.days.ago),
        ]
      end

      it { is_expected.to eq items.map(&:id).reverse }
    end
  end

  describe 'scopes' do
    describe '#published' do
      subject { described_class.published.all }

      before do
        published
        unpublished
      end

      let(:published) { create :news_collection }
      let(:unpublished) { create :news_collection, :unpublished }

      it { is_expected.to include published }
      it { is_expected.not_to include unpublished }
    end
  end
end
