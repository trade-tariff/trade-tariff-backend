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
end
