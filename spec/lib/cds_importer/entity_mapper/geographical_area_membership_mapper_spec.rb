RSpec.describe CdsImporter::EntityMapper::GeographicalAreaMembershipMapper do
  it_behaves_like 'an entity mapper', 'GeographicalAreaMembership', 'GeographicalArea' do
    let(:xml_node) do
      {
        'hjid' => '123',
        'sid' => '234',
        'metainfo' => {
          'opType' => 'U',
          'origin' => 'N',
          'transactionDate' => '2017-08-29T20:14:17',
        },
        'geographicalAreaMembership' => {
          'hjid' => '25864',
          'geographicalAreaGroupSid' => '461273',
          'geographicalAreaSid' => '311',
          'validityStartDate' => '2008-01-01T00:00:00',
          'validityEndDate' => '2020-06-29T20:04:37',
          'metainfo' => {
            'opType' => 'U',
            'origin' => 'N',
            'transactionDate' => '2017-06-29T20:04:37',
          },
        },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: Time.zone.parse('2008-01-01T00:00:00.000Z'),
        validity_end_date: Time.zone.parse('2020-06-29T20:04:37.000Z'),
        national: true,
        operation: 'U',
        operation_date: Date.parse('2017-06-29'),
        hjid: 25_864,
        geographical_area_group_sid: 461_273,
        geographical_area_sid: 311,
      }
    end
  end

  describe '#import' do
    subject(:entity_mapper) { CdsImporter::EntityMapper.new('GeographicalArea', xml_node) }

    context 'when the geographicalAreaMembership node is missing' do
      let(:xml_node) do
        {
          'hjid' => '11939477',
          'metainfo' => { 'opType' => 'C', 'origin' => 'T', 'status' => 'L', 'transactionDate' => '2022-07-21T16:57:13' },
          'sid' => '513',
          'geographicalAreaId' => '4007',
          'geographicalCode' => '1',
          'validityStartDate' => '2021-01-01T00:00:00',
          'geographicalAreaDescriptionPeriod' => {
            'hjid' => '11939478',
            'metainfo' => { 'opType' => 'C', 'origin' => 'T', 'status' => 'L', 'transactionDate' => '2022-07-21T16:57:13' },
            'sid' => '1439',
            'validityStartDate' => '2021-01-01T00:00:00',
            'geographicalAreaDescription' => {
              'hjid' => '11939479',
              'metainfo' => { 'opType' => 'C', 'origin' => 'T', 'status' => 'L', 'transactionDate' => '2022-07-21T16:57:13' },
              'description' => 'Phytosanitary Group 8',
              'language' => { 'hjid' => '9', 'languageId' => 'EN' },
            },
          },
        }
      end

      it { expect { entity_mapper.import }.not_to raise_error }
    end

    context 'when there are multiple geographicalAreaMembership nodes' do
      let(:xml_node) do
        {
          'metainfo' => {
            'opType' => 'U',
            'origin' => 'N',
            'transactionDate' => '2017-06-29T20:04:37',
          },
          'hjid' => '23501',
          'sid' => '114',
          'geographicalAreaId' => '1010',
          'geographicalCode' => '1',
          'validityStartDate' => '1958-01-01T00:00:00',
          'geographicalAreaMembership' => [
            {
              'hjid' => '25654',
              'metainfo' => { 'opType' => 'C', 'origin' => 'T', 'status' => 'L', 'transactionDate' => '2018-12-15T04:15:45' },
              'geographicalAreaGroupSid' => '23590',
              'validityStartDate' => '2004-05-01T00:00:00',
            },
            {
              'hjid' => '25473',
              'metainfo' => { 'opType' => 'C', 'origin' => 'T', 'status' => 'L', 'transactionDate' => '2018-12-15T04:15:46' },
              'geographicalAreaGroupSid' => '23575',
              'validityStartDate' => '2007-01-01T00:00:00',
            },
          ],
        }
      end

      let(:expected_hash) do
        {
          'metainfo' => {
            'opType' => 'U',
            'origin' => 'N',
            'transactionDate' => '2017-06-29T20:04:37',
          },
          'hjid' => '23501',
          'sid' => '114',
          'geographicalAreaId' => '1010',
          'geographicalCode' => '1',
          'validityStartDate' => '1958-01-01T00:00:00',
          'geographicalAreaMembership' => [
            {
              'hjid' => '25654',
              'metainfo' => { 'opType' => 'C', 'origin' => 'T', 'status' => 'L', 'transactionDate' => '2018-12-15T04:15:45' },
              'geographicalAreaGroupSid' => 114,
              'validityStartDate' => '2004-05-01T00:00:00',
              'geographicalAreaSid' => 331,
            },
            {
              'hjid' => '25473',
              'metainfo' => { 'opType' => 'C', 'origin' => 'T', 'status' => 'L', 'transactionDate' => '2018-12-15T04:15:46' },
              'geographicalAreaGroupSid' => 114,
              'validityStartDate' => '2007-01-01T00:00:00',
              'geographicalAreaSid' => 112,
            },
          ],
        }
      end

      before do
        create(:geographical_area, :group, geographical_area_id: '1010', geographical_area_sid: 114)
        create(:geographical_area, hjid: 23_575, geographical_area_sid: 112)
        create(:geographical_area, hjid: 23_590, geographical_area_sid: 331)
      end

      it 'mutates the xml node to hold the correct geographical_area_sid and geographical_area_group_sid values' do
        entity_mapper.import

        expect(xml_node).to eq(expected_hash)
      end

      it 'creates the correct memberships' do
        yielded_objects = []

        entity_mapper.import do |entity|
          yielded_objects << entity
        end

        expect(yielded_objects.map(&:instance).map { |obj| { obj.class.name.to_sym => obj.values } })
          .to include(
            { GeographicalArea: hash_including(geographical_area_id: '1010', geographical_area_sid: 114) },
            { GeographicalAreaMembership: hash_including(geographical_area_sid: 331, hjid: 25_654, geographical_area_group_sid: 114) },
            { GeographicalAreaMembership: hash_including(geographical_area_sid: 112, hjid: 25_473, geographical_area_group_sid: 114) },
          )
      end

      context 'when the xml node is missing a membership group sid' do
        before do
          allow(ActiveSupport::Notifications).to receive(:instrument).and_call_original
          xml_node['geographicalAreaMembership'].first.delete('geographicalAreaGroupSid')
        end

        let(:expected_hash) do
          {
            'metainfo' => {
              'opType' => 'U',
              'origin' => 'N',
              'transactionDate' => '2017-06-29T20:04:37',
            },
            'hjid' => '23501',
            'sid' => '114',
            'geographicalAreaId' => '1010',
            'geographicalCode' => '1',
            'validityStartDate' => '1958-01-01T00:00:00',
            'geographicalAreaMembership' => [
              {
                'metainfo' => { 'opType' => 'C', 'origin' => 'T', 'status' => 'L', 'transactionDate' => '2018-12-15T04:15:46' },
                'hjid' => '25473',
                'geographicalAreaGroupSid' => 114,
                'validityStartDate' => '2007-01-01T00:00:00',
                'geographicalAreaSid' => 112,
              },
            ],
          }
        end

        let(:expected_message) { "Skipping membership import due to missing geographical area group sid. hjid is 25654\n" }

        it 'mutates the xml node to hold the correct geographical_area_sid and geographical_area_group_sid values' do
          entity_mapper.import

          expect(xml_node).to eq(expected_hash)
        end

        it 'instruments a message about the missing sid' do
          entity_mapper.import

          expect(ActiveSupport::Notifications).to have_received(:instrument).with(
            'apply.import_warnings',
            message: expected_message, xml_node:,
          )
        end
      end
    end

    context 'when the node is a GeographicalArea with a single member' do
      before do
        create(:geographical_area, hjid: 23_590, geographical_area_sid: 331)
      end

      let(:xml_node) do
        {
          'hjid' => '23501',
          'sid' => '114',
          'geographicalAreaId' => '1010',
          'geographicalCode' => '1',
          'validityStartDate' => '1958-01-01T00:00:00',
          'geographicalAreaMembership' => {
            'hjid' => '25654',
            'metainfo' => { 'opType' => 'C', 'origin' => 'T', 'status' => 'L', 'transactionDate' => '2018-12-15T04:15:45' },
            'geographicalAreaGroupSid' => '23590',
            'validityStartDate' => '2004-05-01T00:00:00',
          },
        }
      end

      let(:expected_hash) do
        {
          'hjid' => '23501',
          'sid' => '114',
          'geographicalAreaId' => '1010',
          'geographicalCode' => '1',
          'validityStartDate' => '1958-01-01T00:00:00',
          'geographicalAreaMembership' => [
            {
              'hjid' => '25654',
              'metainfo' => { 'opType' => 'C', 'origin' => 'T', 'status' => 'L', 'transactionDate' => '2018-12-15T04:15:45' },
              'geographicalAreaGroupSid' => 114,
              'validityStartDate' => '2004-05-01T00:00:00',
              'geographicalAreaSid' => 331,
            },
          ],
        }
      end

      it 'mutates the xml node to hold the correct geographical_area_sid and geographical_area_group_sid values' do
        entity_mapper.import

        expect(xml_node).to eq(expected_hash)
      end
    end
  end
end
