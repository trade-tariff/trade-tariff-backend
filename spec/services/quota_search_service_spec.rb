# rubocop:disable RSpec/MultipleMemoizedHelpers
describe QuotaSearchService do
  subject(:service) { described_class.new(filter, current_page, per_page) }

  around do |example|
    TimeMachine.now { example.run }
  end

  let(:validity_start_date) { Date.yesterday }
  let(:quota_order_number1) { create :quota_order_number }
  let!(:measure1) { create :measure, ordernumber: quota_order_number1.quota_order_number_id, validity_start_date: validity_start_date }
  let!(:quota_definition1) do
    create :quota_definition,
           quota_order_number_sid: quota_order_number1.quota_order_number_sid,
           quota_order_number_id: quota_order_number1.quota_order_number_id,
           critical_state: 'Y',
           validity_start_date: validity_start_date
  end
  let!(:quota_order_number_origin1) do
    create :quota_order_number_origin,
           :with_geographical_area,
           quota_order_number_sid: quota_order_number1.quota_order_number_sid
  end

  let(:quota_order_number2) { create :quota_order_number }
  let!(:measure2) { create :measure, ordernumber: quota_order_number2.quota_order_number_id, validity_start_date: validity_start_date }
  let!(:quota_definition2) do
    create :quota_definition,
           quota_order_number_sid: quota_order_number2.quota_order_number_sid,
           quota_order_number_id: quota_order_number2.quota_order_number_id,
           critical_state: 'N',
           validity_start_date: validity_start_date
  end
  let!(:quota_order_number_origin2) do
    create :quota_order_number_origin,
           :with_geographical_area,
           quota_order_number_sid: quota_order_number2.quota_order_number_sid
  end
  let(:current_page) { 1 }
  let(:per_page) { 20 }

  before do
    measure1.update(geographical_area_id: quota_order_number_origin1.geographical_area_id)
    measure2.update(geographical_area_id: quota_order_number_origin2.geographical_area_id)
  end

  describe '#status' do
    let(:filter) { { 'status' => 'not+exhausted' } }

    it 'unescapes status values' do
      expect(service.status).to eq('not_exhausted')
    end
  end

  describe '#call' do
    context 'when filtering by a fully-qualified goods_nomenclature_item_id' do
      let(:filter) { { 'goods_nomenclature_item_id' => measure1.goods_nomenclature_item_id } }

      it 'returns the correct quota definition' do
        expect(service.call).to eq([quota_definition1])
      end
    end

    context 'when filtering by a NOT fully-qualified goods_nomenclature_item_id' do
      let(:filter) { { 'goods_nomenclature_item_id' => measure1.goods_nomenclature_item_id[0..6] } }

      it 'returns the correct quota definition' do
        expect(service.call).to eq([quota_definition1])
      end
    end

    context 'when filtering by the geographical_area_id' do
      let(:filter) { { 'geographical_area_id' => quota_order_number_origin1.geographical_area_id } }

      it 'returns the correct quota definition' do
        expect(service.call).to eq([quota_definition1])
      end
    end

    context 'when filtering by the order number' do
      let(:filter) { { 'order_number' => quota_order_number1.quota_order_number_id } }

      it 'returns the correct quota definition' do
        expect(service.call).to eq([quota_definition1])
      end
    end

    context 'when filtering by the quota definition critical state' do
      let(:filter) { { 'critical' => 'Y' } }

      it 'returns the correct quota definition' do
        expect(service.call).to eq([quota_definition1])
      end
    end

    context 'when filtering by status exhausted' do
      let(:filter) { { 'status' => 'exhausted' } }

      before do
        create :quota_exhaustion_event, quota_definition: quota_definition1
      end

      it 'returns the correct quota definition' do
        expect(service.call).to eq([quota_definition1])
      end
    end

    context 'when filtering by status not exhausted' do
      let(:filter) { { 'status' => 'not_exhausted' } }

      before do
        create :quota_exhaustion_event, quota_definition: quota_definition1
      end

      it 'returns the correct quota definition' do
        expect(service.call).to eq([quota_definition2])
      end
    end

    context 'when filtering by status blocked' do
      let(:filter) { { 'status' => 'blocked' } }

      before do
        create :quota_blocking_period,
               quota_definition_sid: quota_definition1.quota_definition_sid,
               blocking_start_date: Date.current,
               blocking_end_date: 1.year.from_now
      end

      it 'returns the correct quota definition' do
        expect(service.call).to eq([quota_definition1])
      end
    end

    context 'when filtering by status not blocked' do
      let(:filter) { { 'status' => 'not_blocked' } }

      before do
        create :quota_blocking_period,
               quota_definition_sid: quota_definition1.quota_definition_sid,
               blocking_start_date: Date.current,
               blocking_end_date: 1.year.from_now
      end

      it 'returns the correct quota definition' do
        expect(service.call).to eq([quota_definition2])
      end
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
