RSpec.describe Api::User::CommodityChangesService do
  subject(:service) { described_class.new(user, nil, date) }

  let(:date) { Date.yesterday }
  let(:user) { create(:public_user) }
  let(:user_commodity_code_sids) { [123_456, 987_654] }

  before do
    allow(Time.zone).to receive(:yesterday).and_return(date)
    allow(user).to receive(:target_ids_for_my_commodities).and_return(user_commodity_code_sids)
  end

  describe '#call when id is not allowed' do
    let(:user_commodity_code_sids) { [123_456, 987_654] }
    let(:user) { create(:public_user) }
    let(:date) { Date.yesterday }
    let(:service_with_invalid_id) { described_class.new(user, 'not_allowed', date) }

    before do
      allow(Time.zone).to receive(:yesterday).and_return(date)
      allow(user).to receive(:target_ids_for_my_commodities).and_return(user_commodity_code_sids)
      allow(TariffChange).to receive_message_chain(:commodities, :where, :where, :where, :count).and_return(5)
      allow(TariffChange).to receive_message_chain(:commodity_descriptions, :where, :where, :where, :count).and_return(3)
    end

    it 'returns all changes (array) when id is not in allowed list' do
      result = service_with_invalid_id.call
      expect(result).to be_an(Array)
      expect(result.first.id).to eq('ending')
      expect(result.last.id).to eq('classification')
    end
  end

  describe '#call when id is nil' do
    before do
      allow(TariffChange).to receive_message_chain(:commodities, :where, :where, :where, :count).and_return(5)
      allow(TariffChange).to receive_message_chain(:commodity_descriptions, :where, :where, :where, :count).and_return(3)
    end

    it 'returns the correct structure' do
      result = service.call
      expect(result).to be_an(Array)
      expect(result.first.id).to eq('ending')
      expect(result.first.count).to eq(5)
      expect(result.last.id).to eq('classification')
      expect(result.last.count).to eq(3)
    end

    context 'when there are no commodity endings' do
      before do
        allow(TariffChange).to receive_message_chain(:commodities, :where, :where, :where, :count).and_return(0)
      end

      it 'omits commodity endings from the result' do
        result = service.call
        expect(result).not_to(be_any { |change| change.id == 'ending' })
      end
    end

    context 'when there are no classification changes' do
      before do
        allow(TariffChange).to receive_message_chain(:commodity_descriptions, :where, :where, :where, :count).and_return(0)
      end

      it 'omits classification changes from the result' do
        result = service.call
        expect(result).not_to(be_any { |change| change.id == 'classification' })
      end
    end
  end

  describe '#call when id is specified' do
    let(:service_with_id_ending) { described_class.new(user, 'ending', date) }
    let(:service_with_id_classification) { described_class.new(user, 'classification', date) }

    before do
      allow(TariffChange).to receive_message_chain(:commodities, :where, :where, :where, :all).and_return(%i[ending1 ending2])
      allow(TariffChange).to receive_message_chain(:commodities, :where, :where, :where, :count).and_return(2)
      allow(TariffChange).to receive_message_chain(:commodity_descriptions, :where, :where, :where, :all).and_return([:desc1])
      allow(TariffChange).to receive_message_chain(:commodity_descriptions, :where, :where, :where, :count).and_return(1)
    end

    it 'returns a GroupedCommodityChange with correct attributes when id is ending' do
      result = service_with_id_ending.call
      expect(result).to be_a(TariffChanges::GroupedCommodityChange)
      expect(result.id).to eq('ending')
      expect(result.count).to eq(2)
      expect(result.tariff_changes).to eq(%i[ending1 ending2])
    end

    it 'returns a GroupedCommodityChange with correct attributes when id is classification' do
      result = service_with_id_classification.call
      expect(result).to be_a(TariffChanges::GroupedCommodityChange)
      expect(result.id).to eq('classification')
      expect(result.count).to eq(1)
      expect(result.tariff_changes).to eq([:desc1])
    end
  end
end
