# rubocop:disable RSpec/MultipleMemoizedHelpers
RSpec.describe QuotaSearchService do
  subject(:service) { described_class.new(filter, current_page, per_page, Time.zone.today) }

  around do |example|
    TimeMachine.now { example.run }
  end

  let(:validity_start_date) { Time.zone.yesterday }
  let(:quota_order_number1) { create :quota_order_number }
  let!(:measure1) { create :measure, :with_goods_nomenclature, ordernumber: quota_order_number1.quota_order_number_id, validity_start_date: }
  let!(:quota_definition1) do
    create :quota_definition,
           quota_order_number_sid: quota_order_number1.quota_order_number_sid,
           quota_order_number_id: quota_order_number1.quota_order_number_id,
           critical_state: 'Y',
           validity_start_date:
  end
  let!(:quota_order_number_origin1) do
    create :quota_order_number_origin,
           :with_geographical_area,
           quota_order_number_sid: quota_order_number1.quota_order_number_sid
  end
  let!(:duplicate_measure) { create :measure, :with_goods_nomenclature, ordernumber: quota_order_number1.quota_order_number_id, validity_start_date: validity_start_date + 1.hour }

  let(:quota_order_number2) { create :quota_order_number }
  let(:goods_nomenclature2) { create :goods_nomenclature, parent: create(:heading) }
  let!(:measure2) { create :measure, goods_nomenclature: goods_nomenclature2, ordernumber: quota_order_number2.quota_order_number_id, validity_start_date: }
  let!(:quota_definition2) do
    create :quota_definition,
           quota_order_number_sid: quota_order_number2.quota_order_number_sid,
           quota_order_number_id: quota_order_number2.quota_order_number_id,
           critical_state: 'N',
           validity_start_date:
  end
  let(:geographical_area_with_members) { create(:geographical_area, :with_members) }
  let(:geographical_area_member) { geographical_area_with_members.contained_geographical_areas.first }
  let!(:quota_order_number_origin2) do
    create(
      :quota_order_number_origin,
      geographical_area: geographical_area_with_members,
      quota_order_number_sid: quota_order_number2.quota_order_number_sid,
    )
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
    context 'when filtering by a quota order number id' do
      let(:filter) { { 'order_number' => duplicate_measure.ordernumber } }

      it 'returns the correct quota definition' do
        expect(service.call).to eq([quota_definition1])
      end
    end

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

      it_with_refresh_materialized_view 'returns the correct quota definition' do
        expect(service.call).to eq([quota_definition1])
      end
    end

    context 'when filtering by the geographical_area_id of a member' do
      let(:filter) { { 'geographical_area_id' => geographical_area_member.geographical_area_id } }

      it_with_refresh_materialized_view 'returns the correct quota definition' do
        expect(service.call).to eq([quota_definition2])
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
               blocking_start_date: Time.zone.today,
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
               blocking_start_date: Time.zone.today,
               blocking_end_date: 1.year.from_now
      end

      it 'returns the correct quota definition' do
        expect(service.call).to eq([quota_definition2])
      end
    end

    context 'when a quota definition is end dated' do
      before do
        # Modifying records directly because oplog plugin doesn't support dataset CRUD operations
        QuotaDefinition.each do |qd|
          qd.validity_end_date = Date.yesterday
          qd.save
        end
      end

      let(:filter) { {} }

      it_with_refresh_materialized_view 'return empty' do
        expect(service.call).to be_empty
      end
    end
  end

  describe '#pagination_record_count' do
    subject { service.tap(&:call).pagination_record_count }

    let(:filter) { {} }

    context 'with records' do
      it { is_expected.to eq 2 }
    end

    context 'with end dated quota definitions' do
      before do
        # Modifying records directly because oplog plugin doesn't support dataset CRUD operations
        QuotaDefinition.each do |qd|
          qd.validity_end_date = Date.yesterday
          qd.save
        end
      end

      it_with_refresh_materialized_view 'return zero' do
        expect(service.tap(&:call).pagination_record_count).to eq 0
      end
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
