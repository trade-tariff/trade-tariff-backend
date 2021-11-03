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

  describe 'scopes' do
    describe '.for_service' do
      subject(:results) { described_class.for_service(service_name) }

      let(:uk_page) { create :news_item, show_on_uk: true, show_on_xi: false }
      let(:xi_page) { create :news_item, show_on_uk: false, show_on_xi: true }
      let(:both_page) { create :news_item, show_on_uk: true, show_on_xi: true }
      let(:neither_page) { create :news_item, show_on_uk: false, show_on_xi: false }

      context 'without service name' do
        let(:service_name) { nil }

        it { is_expected.to include uk_page }
        it { is_expected.to include xi_page }
        it { is_expected.to include both_page }
        it { is_expected.to include neither_page }
      end

      context 'with uk' do
        let(:service_name) { 'uk' }

        it { is_expected.to include uk_page }
        it { is_expected.not_to include xi_page }
        it { is_expected.to include both_page }
        it { is_expected.not_to include neither_page }
      end

      context 'with xi' do
        let(:service_name) { 'xi' }

        it { is_expected.to include xi_page }
        it { is_expected.not_to include uk_page }
        it { is_expected.to include both_page }
        it { is_expected.not_to include neither_page }
      end

      context 'with an invalid service' do
        let(:service_name) { 'invalid' }

        it { expect { results }.to raise_exception Sequel::RecordNotFound }
      end
    end

    describe '.for_target' do
      subject(:results) { described_class.for_target(target) }

      let :home_page do
        create :news_item, show_on_home_page: true, show_on_updates_page: false
      end

      let :updates_page do
        create :news_item, show_on_home_page: false, show_on_updates_page: true
      end

      let :both_page do
        create :news_item, show_on_home_page: true, show_on_updates_page: true
      end

      let :neither_page do
        create :news_item, show_on_home_page: false, show_on_updates_page: false
      end

      context 'without target' do
        let(:target) { nil }

        it { is_expected.to include home_page }
        it { is_expected.to include updates_page }
        it { is_expected.to include both_page }
        it { is_expected.to include neither_page }
      end

      context 'with home' do
        let(:target) { 'home' }

        it { is_expected.to include home_page }
        it { is_expected.not_to include updates_page }
        it { is_expected.to include both_page }
        it { is_expected.not_to include neither_page }
      end

      context 'with updates' do
        let(:target) { 'updates' }

        it { is_expected.to include updates_page }
        it { is_expected.not_to include home_page }
        it { is_expected.to include both_page }
        it { is_expected.not_to include neither_page }
      end

      context 'with an invalid target' do
        let(:target) { 'invalid' }

        it { expect { results }.to raise_exception Sequel::RecordNotFound }
      end
    end

    describe '.for_today' do
      subject { described_class.for_today }

      let :yesterdays do
        create :news_item, start_date: Time.zone.yesterday, end_date: Time.zone.yesterday
      end

      let :todays do
        create :news_item, start_date: Time.zone.today, end_date: Time.zone.today
      end

      let :tomorrows do
        create :news_item, start_date: Time.zone.tomorrow, end_date: Time.zone.tomorrow
      end

      let :indefinite do
        create :news_item, start_date: Time.zone.today, end_date: nil
      end

      it { is_expected.not_to include yesterdays }
      it { is_expected.to include todays }
      it { is_expected.not_to include tomorrows }
      it { is_expected.to include indefinite }
    end

    describe '.descending' do
      subject { described_class.descending.to_a }

      let!(:published_today) { create :news_item, start_date: Time.zone.today }
      let!(:published_yesterday) { create :news_item, start_date: Time.zone.yesterday }

      it { is_expected.to eql [published_today, published_yesterday] }
    end
  end
end
