# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::User::CommodityChangesService do
  subject(:service) { described_class.new(user, date) }

  let(:user_commodity_code_sids) { [123_456, 987_654] }
  let(:user) { create(:public_user) }
  let(:date) { Date.yesterday }

  before do
    allow(Time.zone).to receive(:yesterday).and_return(date)
    allow(user).to receive(:target_ids_for_my_commodities).and_return(user_commodity_code_sids)
  end

  describe '#call' do
    before do
      allow(TariffChange).to receive_message_chain(:commodities, :where, :where, :where, :count).and_return(5)
      allow(TariffChange).to receive_message_chain(:commodity_descriptions, :where, :where, :where, :count).and_return(3)
    end

    it 'returns the correct structure' do
      result = service.call
      expect(result).to be_an(Array)
      expect(result.first.id).to eq('commodity_endings')
      expect(result.first.count).to eq(5)
      expect(result.last.id).to eq('classification_changes')
      expect(result.last.count).to eq(3)
    end
  end

  describe '#user_commodity_code_sids' do
    it 'returns user commodity code sids' do
      expect(service.send(:user_commodity_code_sids)).to eq(user_commodity_code_sids)
    end
  end
end
