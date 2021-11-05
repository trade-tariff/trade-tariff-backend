require 'rails_helper'

RSpec.describe NewsItem do
  describe 'attributes' do
    it { is_expected.to respond_to :start_date }
    it { is_expected.to respond_to :end_date }
    it { is_expected.to respond_to :title }
    it { is_expected.to respond_to :content }
    it { is_expected.to respond_to :display_style }
    it { is_expected.to respond_to :show_on_xi }
    it { is_expected.to respond_to :show_on_uk }
    it { is_expected.to respond_to :show_on_home_page }
    it { is_expected.to respond_to :show_on_updates_page }
  end

  describe 'validations' do
    subject(:errors) { instance.tap(&:valid?).errors }

    let(:instance) { described_class.new }

    it { is_expected.to include(title: ['is not present']) }
    it { is_expected.to include(content: ['is not present']) }
    it { is_expected.to include(display_style: ['is not present']) }
    it { is_expected.to include(show_on_uk: ['is not present']) }
    it { is_expected.to include(show_on_xi: ['is not present']) }
    it { is_expected.to include(show_on_updates_page: ['is not present']) }
    it { is_expected.to include(show_on_home_page: ['is not present']) }
    it { is_expected.to include(start_date: ['is not present']) }
    it { is_expected.not_to include(end_date: ['is not present']) }

    context 'with blank strings' do
      let(:instance) { described_class.new title: '', content: '' }

      it { is_expected.to include(title: ['is not present']) }
      it { is_expected.to include(content: ['is not present']) }
    end
  end
end
