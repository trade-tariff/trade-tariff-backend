class CommodityChangesQueryStub
  attr_reader :count

  def initialize(count:, records: nil)
    @count = count
    @records = records
  end

  def on_date(_date)
    self
  end

  def for_goods_nomenclature_sids(_goods_nomenclature_sids)
    self
  end

  def where(*_args)
    self
  end

  def all
    @records
  end
end

RSpec.describe Api::User::CommodityChangesService do
  subject(:service) { described_class.new(user, id, date) }

  let(:id) { nil }
  let(:date) { Date.yesterday }
  let(:user) { create(:public_user) }
  let(:user_commodity_code_sids) { [123_456, 987_654] }

  before do
    allow(user).to receive(:target_ids_for_my_commodities).and_return(user_commodity_code_sids)
  end

  def stub_tariff_change_scope(scope, count:, records: nil)
    allow(TariffChange).to receive(scope).and_return(
      CommodityChangesQueryStub.new(count: count, records: records),
    )
  end

  describe '#call' do
    context 'when id is nil' do
      before do
        stub_tariff_change_scope(:commodities, count: 5)
        stub_tariff_change_scope(:commodity_descriptions, count: 3)
      end

      it 'returns both grouped changes' do
        expect(service.call.map(&:id)).to eq(%w[ending classification])
      end

      it 'returns the expected counts' do
        result = service.call

        expect(result.map(&:count)).to eq([5, 3])
      end
    end

    context 'when id is not allowed' do
      let(:id) { 'not_allowed' }

      before do
        stub_tariff_change_scope(:commodities, count: 5)
        stub_tariff_change_scope(:commodity_descriptions, count: 3)
      end

      it 'falls back to all changes' do
        expect(service.call.map(&:id)).to eq(%w[ending classification])
      end
    end

    context 'when there are no commodity endings' do
      before do
        stub_tariff_change_scope(:commodities, count: 0)
        stub_tariff_change_scope(:commodity_descriptions, count: 3)
      end

      it 'omits ending changes' do
        expect(service.call.map(&:id)).to eq(%w[classification])
      end
    end

    context 'when there are no classification changes' do
      before do
        stub_tariff_change_scope(:commodities, count: 5)
        stub_tariff_change_scope(:commodity_descriptions, count: 0)
      end

      it 'omits classification changes' do
        expect(service.call.map(&:id)).to eq(%w[ending])
      end
    end

    context 'when id is ending' do
      let(:id) { 'ending' }

      before do
        stub_tariff_change_scope(:commodities, count: 2, records: %i[ending1 ending2])
      end

      it 'returns the ending group with records' do
        result = service.call

        expect(result).to be_a(TariffChanges::GroupedCommodityChange)
        expect(result.id).to eq('ending')
        expect(result.count).to eq(2)
        expect(result.tariff_changes).to eq(%i[ending1 ending2])
      end
    end

    context 'when id is classification' do
      let(:id) { 'classification' }

      before do
        stub_tariff_change_scope(:commodity_descriptions, count: 1, records: [:desc1])
      end

      it 'returns the classification group with records' do
        result = service.call

        expect(result).to be_a(TariffChanges::GroupedCommodityChange)
        expect(result.id).to eq('classification')
        expect(result.count).to eq(1)
        expect(result.tariff_changes).to eq([:desc1])
      end
    end
  end
end
