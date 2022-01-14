RSpec.describe CdsImporter::EntityMapper do
  subject(:entity_mapper) { described_class.new('AdditionalCode', xml_node) }

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

  describe '#import' do
    context 'when the node is associated to an existing measure that has a footnote' do
      subject(:entity_mapper) { described_class.new('Measure', xml_node) }

      let(:xml_node) do
        {
          'sid' => '12348',
          'metainfo' => {
            'opType' => 'U',
            'origin' => 'N',
            'transactionDate' => '2017-06-29T20:04:37',
          },
        }
      end

      let(:measure) { create(:measure, measure_sid: '12348') }

      before { create(:footnote, :with_measure_association, measure_sid: measure.measure_sid) }

      it 'removes associated footnotes that are missing from the xml node' do
        expect { entity_mapper.import }
          .to change { FootnoteAssociationMeasure.where(measure_sid: measure.measure_sid).count }
          .from(1)
          .to(0)
      end
    end

    context 'when the node is associated to an existing measure that has a footnote that is also in the xml node' do
      subject(:entity_mapper) { described_class.new('Measure', xml_node) }

      let(:xml_node) do
        {
          'sid' => '12348',
          'metainfo' => {
            'opType' => 'U',
            'origin' => 'N',
            'transactionDate' => '2017-06-29T20 =>04:37',
          },
          'footnoteAssociationMeasure' => [
            {
              'hjid' => '11169585',
              'metainfo' => {
                'opType' => 'C',
                'origin' => 'T',
                'status' => 'L',
                'transactionDate' => '2021-04-30T18:02:08',
              },
              'footnote' => {
                'hjid' => '11008707',
                'footnoteId' => footnote.id,
                'footnoteType' => {
                  'hjid' => '11008014',
                  'footnoteTypeId' => 'DS',
                },
              },
            },
          ],
        }
      end

      let(:measure) { create(:measure, measure_sid: '12348') }

      let(:footnote) do
        create(
          :footnote,
          :with_measure_association,
          measure_sid: measure.measure_sid,
        )
      end

      before { footnote }

      it 'does not remove footnote assocations that exist in the xml node' do
        expect { entity_mapper.import }
          .not_to change { FootnoteAssociationMeasure.where(measure_sid: measure.measure_sid).count }
          .from(1)
      end
    end

    context 'when the node is not associated to an existing measure that has a footnote' do
      subject(:entity_mapper) { described_class.new('Measure', xml_node) }

      let(:xml_node) do
        {
          'sid' => '12348',
          'metainfo' => {
            'opType' => 'U',
            'origin' => 'N',
            'transactionDate' => '2017-06-29T20:04:37',
          },
        }
      end

      let(:measure) { create(:measure) } # Missing associated measure sid

      before { create(:footnote, :with_measure_association, measure_sid: measure.measure_sid) }

      it 'does not remove footnote assocations of other unrelated measures' do
        expect { entity_mapper.import }
          .not_to change { FootnoteAssociationMeasure.where(measure_sid: measure.measure_sid).count }
          .from(1)
      end
    end

    context 'when the node is a GeographicalArea with multiple members' do
      subject(:entity_mapper) { described_class.new('GeographicalArea', xml_node) }

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
        expect { entity_mapper.import }
          .to change { GeographicalAreaMembership.where(geographical_area_sid: [331, 112], geographical_area_group_sid: [114]).count }
          .by(2)
      end

      it 'creates the correct area membership associations' do
        entity_mapper.import

        group_geographical_area = GeographicalArea.find(geographical_area_sid: 114)

        expected_area_sids = group_geographical_area.contained_geographical_areas.pluck(:geographical_area_sid).sort

        expect(expected_area_sids).to eq([112, 331])
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
            message: expected_message, xml_node: xml_node,
          )
        end
      end
    end

    context 'when the node is a GeographicalArea with a single member' do
      before do
        create(:geographical_area, hjid: 23_590, geographical_area_sid: 331)
      end

      let(:entity_mapper) do
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

        expect(geographical_area_with_one_member_xml_node).to eq(expected_hash)
      end
    end

    context 'when cds logger enabled' do
      before do
        allow(TariffSynchronizer).to receive(:cds_logger_enabled).and_return(true)
        allow(AdditionalCode.operation_klass).to receive(:insert).and_raise(StandardError, 'foo')
      end

      it { expect { entity_mapper.import }.not_to raise_error }
    end

    context 'when cds logger disabled' do
      before do
        allow(TariffSynchronizer).to receive(:cds_logger_enabled).and_return(false)
        allow(AdditionalCode.operation_klass).to receive(:insert).and_raise(StandardError, 'foo')
      end

      it { expect { entity_mapper.import }.to raise_error(StandardError, 'foo') }
    end

    it { expect { entity_mapper.import }.to change(AdditionalCode, :count).by(1) }
    it { expect(entity_mapper.import).to eql('AdditionalCode::Operation' => 1) }

    it 'saves all attributes for record' do
      entity_mapper.import
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

    it 'selects mappers by mapping root' do
      additional_code_mapper = CdsImporter::EntityMapper::AdditionalCodeMapper.new(xml_node)
      allow(CdsImporter::EntityMapper::AdditionalCodeMapper).to receive(:new).and_return(additional_code_mapper)
      allow(additional_code_mapper).to receive(:parse).and_call_original

      entity_mapper.import

      expect(additional_code_mapper).to have_received(:parse)
    end

    it 'assigns filename' do
      entity_mapper.import
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
          'measureExcludedGeographicalArea' => [
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

      let(:entity_mapper) { described_class.new('Measure', xml_node) }
      let(:measure) { create(:measure, measure_sid: '20130650') }

      it 'does not remove excluded geographical areas that belong to measures not present within the XML increment' do
        create(:geographical_area, geographical_area_sid: '439')
        other_exclusion = create(:measure_excluded_geographical_area)

        entity_mapper.import

        expect(MeasureExcludedGeographicalArea.where(measure_sid: other_exclusion.measure_sid)).to be_present
      end

      context 'when there is an existing exclusion for this measure' do
        it 'does a hard delete of that exclusion' do
          create(:geographical_area, geographical_area_sid: '439')

          create(:measure_excluded_geographical_area, measure_sid: '20130650', excluded_geographical_area: 'IT')

          entity_mapper.import

          expect(MeasureExcludedGeographicalArea.where(excluded_geographical_area: 'IT')).not_to be_present
        end
      end

      it 'does recreate the excluded geographical areas contained within the XML increment' do
        create(:geographical_area, geographical_area_sid: '439')

        expect {
          entity_mapper.import
        }.to change(MeasureExcludedGeographicalArea, :count).from(0).to(1)
      end

      it 'does persist the correct excluded geographical area from the XML increment' do
        create(:geographical_area, geographical_area_sid: '439')

        entity_mapper.import

        expect(MeasureExcludedGeographicalArea.last).to have_attributes(
          measure_sid: 20_130_650,
          excluded_geographical_area: 'CN',
          geographical_area_sid: 439,
        )
      end
    end
  end
end
