RSpec.describe CdsImporter::EntityMapper do
  let(:xml_node) do
    {
      'sid' => '3084',
      'additionalCodeCode' => '169',
      'validityEndDate' => '1996-06-14T23:59:59',
      'validityStartDate' => '1991-06-01T00:00:00',
      'additionalCodeType' => {
        'additionalCodeTypeId' => '8',
      },
      'metainfo' => {
        'origin' => 'N',
        'opType' => 'U',
        'transactionDate' => '2016-07-27T09:20:15',
      },
      'filename' => 'test.gzip',
    }
  end
  let(:mapper) { described_class.new('AdditionalCode', xml_node) }

  describe '::ALL_MAPPERS' do
    subject { described_class::ALL_MAPPERS }

    it { is_expected.not_to be_empty }
  end

  describe '#import' do
    before do
      stub_const(
        'CdsImporter::EntityMapper::ALL_MAPPERS',
        [
          CdsImporter::EntityMapper::MeasureMapper,
          CdsImporter::EntityMapper::MeasureExcludedGeographicalAreaMapper,
          CdsImporter::EntityMapper::AdditionalCodeMapper,
          CdsImporter::EntityMapper::GeographicalAreaMapper,
          CdsImporter::EntityMapper::GeographicalAreaMembershipMapper,
        ],
      )

      create(:geographical_area, hjid: 23_590, geographical_area_sid: 331)
    end

    context 'when the node is a GeographicalArea with multiple members' do
      let(:mapper) do
        described_class.new(
          'GeographicalArea',
          geographical_area_with_multiple_members_xml_node,
        )
      end

      let(:geographical_area_with_multiple_members_xml_node) do
        {
          'hjid' => '23501',
          'sid' => '114',
          'geographicalAreaId' => '1010',
          'geographicalCode' => '1',
          'validityStartDate' => '1958-01-01T00:00:00',
          'geographicalAreaMembership' =>
          [
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
          'hjid' => '23501',
          'sid' => '114',
          'geographicalAreaId' => '1010',
          'geographicalCode' => '1',
          'validityStartDate' => '1958-01-01T00:00:00',
          'geographicalAreaMembership' =>
            [
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
        create(:geographical_area, hjid: 23_575, geographical_area_sid: 112)
      end

      it 'mutates the xml node to hold the correct geographical_area_sid and geographical_area_group_sid values' do
        mapper.import

        expect(geographical_area_with_multiple_members_xml_node).to eq(expected_hash)
      end

      context 'when the xml node is missing an membership group sid' do
        before do
          allow(ActiveSupport::Notifications).to receive(:instrument).and_call_original
          geographical_area_with_multiple_members_xml_node['geographicalAreaMembership'].first.delete('geographicalAreaGroupSid')
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
                'hjid' => '25473',
                'metainfo' => { 'opType' => 'C', 'origin' => 'T', 'status' => 'L', 'transactionDate' => '2018-12-15T04:15:46' },
                'geographicalAreaGroupSid' => 114,
                'validityStartDate' => '2007-01-01T00:00:00',
                'geographicalAreaSid' => 112,
              },
            ],
          }
        end

        let(:expected_message) { "Skipping membership import due to missing geographical area group sid. hjid is 25654\n" }

        let(:expected_xml_node) do
          {
            'hjid' => '23501',
            'sid' => '114',
            'geographicalAreaId' => '1010',
            'geographicalCode' => '1',
            'validityStartDate' => '1958-01-01T00:00:00',
            'geographicalAreaMembership' => [
              { 'hjid' => '25473', 'metainfo' => { 'opType' => 'C', 'origin' => 'T', 'status' => 'L', 'transactionDate' => '2018-12-15T04:15:46' }, 'geographicalAreaGroupSid' => 114, 'validityStartDate' => '2007-01-01T00:00:00', 'geographicalAreaSid' => 112 },
            ],
          }
        end

        it 'mutates the xml node to hold the correct geographical_area_sid and geographical_area_group_sid values' do
          mapper.import

          expect(geographical_area_with_multiple_members_xml_node).to eq(expected_hash)
        end

        it 'instruments a message about the missing sid' do
          mapper.import

          expect(ActiveSupport::Notifications).to have_received(:instrument).with(
            'apply.import_warnings',
            message: expected_message, xml_node: expected_xml_node,
          )
        end
      end
    end

    context 'when the node is a GeographicalArea with a single member' do
      let(:mapper) do
        described_class.new(
          'GeographicalArea',
          geographical_area_with_one_member_xml_node,
        )
      end

      let(:geographical_area_with_one_member_xml_node) do
        {
          'hjid' => '23501',
          'sid' => '114',
          'geographicalAreaId' => '1010',
          'geographicalCode' => '1',
          'validityStartDate' => '1958-01-01T00:00:00',
          'geographicalAreaMembership' =>
          {
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
          'geographicalAreaMembership' =>
            [
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
        mapper.import

        expect(geographical_area_with_one_member_xml_node).to eq(expected_hash)
      end
    end

    context 'when cds logger enabled' do
      before do
        allow(TariffSynchronizer).to receive(:cds_logger_enabled).and_return(true)
      end

      it 'calls safe method' do
        expect(mapper).to receive(:save_record)
        mapper.import
      end
    end

    context 'when cds logger disabled' do
      it 'calls bang method' do
        expect(mapper).to receive(:save_record!)
        mapper.import
      end

      it 'raises an error and stop import' do
        allow(AdditionalCode::Operation).to receive(:insert).and_raise(StandardError)
        expect { mapper.import }.to raise_error(StandardError)
      end
    end

    it 'calls insert method for operation class' do
      expect(AdditionalCode::Operation).to receive(:insert).with(
        hash_including(additional_code: '169', additional_code_sid: 3084, additional_code_type_id: '8', operation: 'U', filename: 'test.gzip'),
      )
      mapper.import
    end

    it 'saves record for any instance' do
      expect { mapper.import }.to change(AdditionalCode, :count).by(1)
    end

    it 'saves all attributes for record' do
      mapper.import
      record = AdditionalCode.last
      aggregate_failures do
        expect(record.additional_code).to eq '169'
        expect(record.additional_code_sid).to eq 3084
        expect(record.additional_code_type_id).to eq '8'
        expect(record.operation).to eq :update
        expect(record.validity_start_date.to_s).to eq '1991-06-01 00:00:00 UTC'
        expect(record.validity_end_date.to_s).to eq '1996-06-14 23:59:59 UTC'
        expect(record.filename).to eq 'test.gzip'
        expect(record.national).to eq true
      end
    end

    it 'records INSERTs performed' do
      expect(mapper.import).to eql({
        'AdditionalCode::Operation' => 1,
      })
    end

    it 'selects mappers by mapping root' do
      expect_any_instance_of(CdsImporter::EntityMapper::AdditionalCodeMapper).to receive(:parse).and_call_original
      mapper.import
    end

    it 'assigns filename' do
      mapper.import
      expect(AdditionalCode.last.filename).to eq 'test.gzip'
    end

    context 'when measureExcludedGeographicalArea changes are present' do
      let(:xml_node) do
        {
          'sid' => '20130650',
          'validityStartDate' => '2021-01-01T00:00:00',
          'metainfo' => {
            'opType' => 'C',
            'origin' => 'T',
            'status' => 'L',
            'transactionDate' => '2021-02-01T17:42:46',
          },
          'measureExcludedGeographicalArea' =>
          [
            {
              'metainfo' => {
                'opType' => 'C',
                'origin' => 'T',
                'status' => 'L',
                'transactionDate' => '2021-02-01T17:42:46',
              },
              'geographicalArea' => {
                'hjid' => '23808',
                'sid' => '439',
                'geographicalAreaId' => 'CN',
                'validityStartDate' => '1984-01-01T00:00:00',
              },
            },
          ],
        }
      end

      let(:mapper) { described_class.new('Measure', xml_node) }
      let(:measure) { create(:measure, measure_sid: '20130650') }

      it 'does not remove excluded geographical areas that belong to measures not present within the XML increment' do
        create(:geographical_area, geographical_area_sid: '439')
        other_exclusion = create(:measure_excluded_geographical_area)

        mapper.import

        expect(MeasureExcludedGeographicalArea[measure_sid: other_exclusion.measure_sid]).to be_present
      end

      context 'when the xml node is missing the root sid for the measure' do
        before do
          allow(ActiveSupport::Notifications).to receive(:instrument).and_call_original
          xml_node.delete('sid')
        end

        let(:expected_message) do
          'Skipping removal of measure geographical exclusions due to missing measure sid.'
        end

        let(:expected_xml_node) do
          {
            'validityStartDate' => '2021-01-01T00:00:00',
            'metainfo' => {
              'opType' => 'C', 'origin' => 'T', 'status' => 'L', 'transactionDate' => '2021-02-01T17:42:46'
            },
            'measureExcludedGeographicalArea' => [
              {
                'metainfo' => { 'opType' => 'C', 'origin' => 'T', 'status' => 'L', 'transactionDate' => '2021-02-01T17:42:46' },
                'geographicalArea' => { 'hjid' => '23808', 'sid' => '439', 'geographicalAreaId' => 'CN', 'validityStartDate' => '1984-01-01T00:00:00' },
              },
            ],
          }
        end

        it 'does not mutate the xml node' do
          expect { mapper.import }.not_to change { xml_node }
        end

        it 'instruments a message about the missing sid' do
          mapper.import

          expect(ActiveSupport::Notifications).to have_received(:instrument).with(
            'apply.import_warnings', message: expected_message, xml_node: expected_xml_node
          )
        end
      end

      context 'when there is an existing exclusion for this measure' do
        it 'does a hard delete of that exclusion' do
          create(:geographical_area, geographical_area_sid: '439')

          create(:measure_excluded_geographical_area, measure_sid: '20130650', excluded_geographical_area: 'IT')

          mapper.import

          expect(MeasureExcludedGeographicalArea[excluded_geographical_area: 'IT']).not_to be_present
        end
      end

      it 'does recreate the excluded geographical areas contained within the XML increment' do
        create(:geographical_area, geographical_area_sid: '439')

        expect {
          mapper.import
        }.to change(MeasureExcludedGeographicalArea, :count).from(0).to(1)
      end

      it 'does persist the correct excluded geographical area from the XML increment' do
        create(:geographical_area, geographical_area_sid: '439')

        mapper.import

        expect(MeasureExcludedGeographicalArea.last).to have_attributes(
          measure_sid: 20_130_650,
          excluded_geographical_area: 'CN',
          geographical_area_sid: 439,
        )
      end
    end
  end
end
