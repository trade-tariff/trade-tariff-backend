RSpec.describe QuotaSearchService do
  subject(:service) { described_class.new(filter, 1, 20, Time.zone.today) }

  around do |example|
    TimeMachine.now { example.run }
  end

  describe '#status' do
    let(:filter) { { 'status' => 'not+exhausted' } }

    it 'unescapes status values' do
      expect(service.status).to eq('not_exhausted')
    end
  end

  describe '#call' do
    let!(:quota_fixtures) { create_quota_fixtures }

    context 'when filtering by a quota order number id' do
      let(:filter) { { 'order_number' => quota_fixtures[:first][:duplicate_measure].ordernumber } }

      it 'returns the correct quota definition' do
        expect(service.call).to eq([quota_fixtures[:first][:definition]])
      end
    end

    context 'when filtering by a fully-qualified goods_nomenclature_item_id' do
      let(:filter) { { 'goods_nomenclature_item_id' => quota_fixtures[:first][:measure].goods_nomenclature_item_id } }

      it 'returns the correct quota definition' do
        expect(service.call).to eq([quota_fixtures[:first][:definition]])
      end
    end

    context 'when filtering by a NOT fully-qualified goods_nomenclature_item_id' do
      let(:filter) { { 'goods_nomenclature_item_id' => quota_fixtures[:first][:measure].goods_nomenclature_item_id[0..6] } }

      it 'returns the correct quota definition' do
        expect(service.call).to eq([quota_fixtures[:first][:definition]])
      end
    end

    context 'when filtering by the geographical_area_id' do
      let(:filter) { { 'geographical_area_id' => quota_fixtures[:first][:origin].geographical_area_id } }

      it_with_refresh_materialized_view 'returns the correct quota definition' do
        expect(service.call).to eq([quota_fixtures[:first][:definition]])
      end
    end

    context 'when filtering by the geographical_area_id of a member' do
      let(:filter) { { 'geographical_area_id' => quota_fixtures[:second][:geographical_area_member].geographical_area_id } }

      it_with_refresh_materialized_view 'returns the correct quota definition' do
        expect(service.call).to eq([quota_fixtures[:second][:definition]])
      end
    end

    context 'when filtering by the order number' do
      let(:filter) { { 'order_number' => quota_fixtures[:first][:order_number].quota_order_number_id } }

      it 'returns the correct quota definition' do
        expect(service.call).to eq([quota_fixtures[:first][:definition]])
      end
    end

    context 'when filtering by the quota definition critical state' do
      let(:filter) { { 'critical' => 'Y' } }

      it 'returns the correct quota definition' do
        expect(service.call).to eq([quota_fixtures[:first][:definition]])
      end
    end

    context 'when filtering by status exhausted' do
      let(:filter) { { 'status' => 'exhausted' } }

      before do
        create :quota_exhaustion_event, quota_definition: quota_fixtures[:first][:definition]
      end

      it 'returns the correct quota definition' do
        expect(service.call).to eq([quota_fixtures[:first][:definition]])
      end
    end

    context 'when filtering by status not exhausted' do
      let(:filter) { { 'status' => 'not_exhausted' } }

      before do
        create :quota_exhaustion_event, quota_definition: quota_fixtures[:first][:definition]
      end

      it 'returns the correct quota definition' do
        expect(service.call).to eq([quota_fixtures[:second][:definition]])
      end
    end

    context 'when filtering by status blocked' do
      let(:filter) { { 'status' => 'blocked' } }

      before do
        create :quota_blocking_period,
               quota_definition_sid: quota_fixtures[:first][:definition].quota_definition_sid,
               blocking_start_date: Time.zone.today,
               blocking_end_date: 1.year.from_now
      end

      it 'returns the correct quota definition' do
        expect(service.call).to eq([quota_fixtures[:first][:definition]])
      end
    end

    context 'when filtering by status not blocked' do
      let(:filter) { { 'status' => 'not_blocked' } }

      before do
        create :quota_blocking_period,
               quota_definition_sid: quota_fixtures[:first][:definition].quota_definition_sid,
               blocking_start_date: Time.zone.today,
               blocking_end_date: 1.year.from_now
      end

      it 'returns the correct quota definition' do
        expect(service.call).to eq([quota_fixtures[:second][:definition]])
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

    before do
      create_quota_fixtures
    end

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

  def create_quota_fixtures
    {
      first: create_quota_fixture(critical_state: 'Y', duplicate_measure: true),
      second: create_quota_fixture(critical_state: 'N', geographical_area_with_members: true),
    }
  end

  def create_quota_fixture(critical_state:, duplicate_measure: false, geographical_area_with_members: false)
    validity_start_date = Time.zone.yesterday
    order_number = create(:quota_order_number)
    measure = if duplicate_measure
                create(
                  :measure,
                  :with_goods_nomenclature,
                  ordernumber: order_number.quota_order_number_id,
                  validity_start_date:,
                )
              else
                goods_nomenclature = create(:goods_nomenclature, parent: create(:heading))
                create(
                  :measure,
                  goods_nomenclature:,
                  ordernumber: order_number.quota_order_number_id,
                  validity_start_date:,
                )
              end
    definition = create(
      :quota_definition,
      quota_order_number_sid: order_number.quota_order_number_sid,
      quota_order_number_id: order_number.quota_order_number_id,
      critical_state:,
      validity_start_date:,
    )
    geographical_area = create(
      :geographical_area,
      *(:with_members if geographical_area_with_members),
    )
    origin = create(
      :quota_order_number_origin,
      geographical_area:,
      quota_order_number_sid: order_number.quota_order_number_sid,
    )
    measure.update(geographical_area_id: origin.geographical_area_id)

    fixture = {
      order_number:,
      measure:,
      definition:,
      origin:,
      geographical_area_member: geographical_area.contained_geographical_areas.first,
    }
    if duplicate_measure
      fixture[:duplicate_measure] = create(
        :measure,
        :with_goods_nomenclature,
        ordernumber: order_number.quota_order_number_id,
        validity_start_date: validity_start_date + 1.hour,
      )
    end
    fixture
  end
end
