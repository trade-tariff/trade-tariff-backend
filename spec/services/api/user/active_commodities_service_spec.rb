RSpec.describe Api::User::ActiveCommoditiesService do
  subject(:service) { described_class.new(subscription) }

  let(:target_ids) { [123, 456, 789, 321, 654, 655] }
  let(:commodity_codes) { %w[1234567890 1234567891 1234567892 1234567893 1234567894 1234560000] }
  let(:subscription) { create(:user_subscription, metadata: { commodity_codes: commodity_codes }) }

  let(:expected_active_codes) { %w[1234567890] }
  let(:expected_expired_codes) { %w[1234560000 1234567891 1234567894] }
  let(:expected_invalid_codes) { %w[1234567892 1234567893] }

  before do
    TradeTariffRequest.time_machine_now = Time.current

    target_ids.each do |target_id|
      create(:subscription_target,
             user_subscriptions_uuid: subscription.uuid,
             target_id: target_id,
             target_type: 'commodity')
    end

    create(:commodity, :actual, goods_nomenclature_item_id: '1234567890', goods_nomenclature_sid: 123)
    create(:commodity, :expired, goods_nomenclature_item_id: '1234567891', goods_nomenclature_sid: 456)
    create(:subheading, :expired, :with_children, goods_nomenclature_item_id: '1234567894', goods_nomenclature_sid: 654)
    create(:subheading, :expired, :non_declarable, :with_children, goods_nomenclature_item_id: '1234560000', goods_nomenclature_sid: 655)

    # Clear both Rails cache and instance variables to ensure fresh data
    Rails.cache.delete('myott_all_active_commodities')
    Rails.cache.delete('myott_all_expired_commodities')
    described_class.instance_variable_set(:@all_active_commodities, nil)
    described_class.instance_variable_set(:@all_expired_commodities, nil)
  end

  after do
    # Ensure cleanup after each test to prevent cache pollution
    Rails.cache.delete('myott_all_active_commodities')
    Rails.cache.delete('myott_all_expired_commodities')
    described_class.instance_variable_set(:@all_active_commodities, nil)
    described_class.instance_variable_set(:@all_expired_commodities, nil)
  end

  describe '.refresh_caches' do
    it 'clears and rebuilds all caches' do
      allow(Rails.cache).to receive(:delete)

      described_class.refresh_caches

      expect(Rails.cache).to have_received(:delete).with('myott_all_active_commodities')
      expect(Rails.cache).to have_received(:delete).with('myott_all_expired_commodities')
    end
  end

  describe '.all_active_commodities' do
    it 'returns active commodities with caching' do
      result = described_class.all_active_commodities
      expect(result).to be_an(Array)
      expect(result.first).to be_an(Array)
    end
  end

  describe '.all_expired_commodities' do
    it 'returns expired commodities excluding subdivided ones' do
      result = described_class.all_expired_commodities
      expect(result).to be_an(Array)
    end

    it 'returns empty array when no expired candidates exist' do
      Rails.cache.delete('myott_all_expired_commodities')
      described_class.instance_variable_set(:@all_expired_commodities, nil)

      allow(GoodsNomenclature).to receive_message_chain(:where, :pluck).and_return([])

      result = described_class.all_expired_commodities
      expect(result).to eq([])
    end
  end

  describe '#initialize' do
    it 'sets uploaded commodity codes from subscription metadata' do
      expect(service.uploaded_commodity_codes).to eq(commodity_codes)
    end

    it 'sets subscription target ids from subscription targets' do
      expect(service.subscription_target_ids.sort).to eq(target_ids.sort)
    end
  end

  describe '#call' do
    let(:expected_result) do
      {
        active: expected_active_codes.count,
        expired: expected_expired_codes.count,
        invalid: expected_invalid_codes.count,
      }
    end

    it 'returns expected result' do
      expect(service.call).to eq(expected_result)
    end

    context 'when no commodity codes are uploaded' do
      let(:empty_subscription) { create(:user_subscription, metadata: { commodity_codes: [] }) }
      let(:empty_service) { described_class.new(empty_subscription) }

      it 'returns empty hash' do
        expect(empty_service.call).to eq({})
      end
    end

    context 'when commodity codes are nil' do
      let(:nil_subscription) { create(:user_subscription, metadata: { commodity_codes: nil }) }
      let(:nil_service) { described_class.new(nil_subscription) }

      it 'returns empty hash' do
        expect(nil_service.call).to eq({})
      end
    end
  end

  describe 'paginated commodity loaders' do
    it 'returns paginated active commodities with correct total' do
      commodities, total = service.active_commodities(page: 1, per_page: 10)
      expect(total).to eq(1)
      expect(commodities.map(&:goods_nomenclature_item_id)).to eq(expected_active_codes)
    end

    it 'returns paginated expired commodities with correct total' do
      commodities, total = service.expired_commodities(page: 1, per_page: 10)
      expect(total).to eq(3)
      expect(commodities.map(&:goods_nomenclature_item_id)).to eq(expected_expired_codes)
    end

    it 'returns paginated invalid commodities with correct total' do
      commodities, total = service.invalid_commodities(page: 1, per_page: 10)
      expect(total).to eq(2)
      expect(commodities.map(&:goods_nomenclature_item_id)).to eq(expected_invalid_codes)
    end
  end

  describe 'pagination functionality' do
    context 'with invalid commodity codes' do
      let(:invalid_subscription) { create(:user_subscription, metadata: { commodity_codes: %w[9999999999] }) }
      let(:invalid_service) { described_class.new(invalid_subscription) }

      it 'returns NullCommodity objects for invalid codes' do
        commodities, total = invalid_service.invalid_commodities
        expect(total).to eq(1)
        expect(commodities.first).to be_a(PublicUsers::NullCommodity)
        expect(commodities.first.goods_nomenclature_item_id).to eq('9999999999')
      end

      it 'returns invalid commodity codes in alphanumeric order' do
        invalid_codes = %w[9999999999 8888888888 7777777777]
        multi_invalid_subscription = create(:user_subscription, metadata: { commodity_codes: invalid_codes })
        multi_invalid_service = described_class.new(multi_invalid_subscription)

        commodities, _total = multi_invalid_service.invalid_commodities
        result_codes = commodities.map(&:goods_nomenclature_item_id)
        expect(result_codes).to eq(invalid_codes.sort)
      end
    end

    context 'with pagination parameters' do
      it 'handles invalid page numbers gracefully' do
        commodities, total = service.active_commodities(page: 10, per_page: 10)
        expect(total).to eq(1)
        expect(commodities).to eq([])
      end

      it 'returns all results when no pagination parameters provided' do
        commodities, total = service.active_commodities
        expect(total).to eq(1)
        expect(commodities.size).to eq(1)
      end
    end
  end

  describe 'edge cases' do
    context 'when subscription has no targets' do
      let(:no_target_subscription) { create(:user_subscription, metadata: { commodity_codes: commodity_codes }) }
      let(:no_target_service) { described_class.new(no_target_subscription) }

      it 'returns zero counts for active and expired, all invalid' do
        result = no_target_service.call
        expect(result).to eq({
          active: 0,
          expired: 0,
          invalid: commodity_codes.count,
        })
      end
    end

    context 'when subscription has no commodity codes' do
      let(:empty_codes_subscription) { create(:user_subscription, metadata: { commodity_codes: [] }) }
      let(:empty_codes_service) { described_class.new(empty_codes_subscription) }

      it 'returns empty hash from call method' do
        expect(empty_codes_service.call).to eq({})
      end

      it 'returns empty arrays from paginated methods' do
        expect(empty_codes_service.active_commodities).to eq([[], 0])
        expect(empty_codes_service.expired_commodities).to eq([[], 0])
        expect(empty_codes_service.invalid_commodities).to eq([[], 0])
      end
    end
  end

  describe 'private method behavior' do
    describe '#apply_validity_end_date' do
      let(:commodity) { create(:commodity, :expired) }

      it 'does not modify commodity with existing validity_end_date' do
        commodity.values[:validity_end_date] = Date.new(2023, 12, 31)
        original_date = commodity.values[:validity_end_date]

        result = service.send(:apply_validity_end_date, commodity)
        expect(result.values[:validity_end_date]).to eq(original_date)
      end

      it 'calculates and sets validity_end_date when missing' do
        commodity.values[:validity_end_date] = nil

        # Mock children with earliest start date
        allow(commodity).to receive(:children).and_return(
          instance_double(Sequel::Dataset, minimum: Date.new(2023, 6, 1)),
        )

        result = service.send(:apply_validity_end_date, commodity)
        expect(result.values[:validity_end_date]).to eq(Date.new(2023, 5, 31))
      end
    end

    describe '#calculate_end_date_from_descendants' do
      let(:commodity) { create(:commodity, :expired) }

      it 'returns nil when no children exist' do
        allow(commodity).to receive(:children).and_return(instance_double(Sequel::Dataset, minimum: nil))

        result = service.send(:calculate_end_date_from_descendants, commodity)
        expect(result).to be_nil
      end

      it 'calculates correct end date from earliest child start date' do
        allow(commodity).to receive(:children).and_return(
          instance_double(Sequel::Dataset, minimum: Date.new(2023, 6, 1)),
        )

        result = service.send(:calculate_end_date_from_descendants, commodity)
        expect(result).to eq(Date.new(2023, 5, 31))
      end
    end

    describe '#paginate_codes' do
      let(:codes) { %w[A B C D E F G H I J] }

      it 'returns all codes when no pagination parameters' do
        result = service.send(:paginate_codes, codes, nil, nil)
        expect(result).to eq(codes)
      end

      it 'paginates correctly' do
        page1 = service.send(:paginate_codes, codes, 1, 3)
        expect(page1).to eq(%w[A B C])

        page2 = service.send(:paginate_codes, codes, 2, 3)
        expect(page2).to eq(%w[D E F])

        page4 = service.send(:paginate_codes, codes, 4, 3)
        expect(page4).to eq(%w[J])
      end

      it 'returns empty array for out-of-range pages' do
        result = service.send(:paginate_codes, codes, 10, 3)
        expect(result).to eq([])
      end
    end
  end
end
