require 'rails_helper'

RSpec.describe News::Collection do
  describe 'attributes' do
    it { is_expected.to respond_to :name }
    it { is_expected.to respond_to :created_at }
    it { is_expected.to respond_to :updated_at }
  end

  describe 'validations' do
    subject(:errors) { instance.tap(&:valid?).errors }

    let(:instance) { described_class.new }

    it { is_expected.to include(name: ['is not present']) }

    context 'with blank name' do
      let(:instance) { described_class.new name: '' }

      it { is_expected.to include(name: ['is not present']) }
    end

    context 'with duplicate collection name' do
      before { create :news_collection, name: 'testing' }

      let(:instance) { described_class.new name: 'testing' }

      it { is_expected.to include(name: ['is already taken']) }
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
end