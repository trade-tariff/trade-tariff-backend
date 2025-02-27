RSpec.describe CdsImporter::EntityMapper::GeographicalAreaMapper do
  let(:xml_node) do
    {
      'hjid' => '23937',
      'metainfo' => {
        'opType' => operation,
        'origin' => 'T',
        'status' => 'L',
        'transactionDate' => '2021-01-29T18:05:33',
      },
      'sid' => '62',
      'geographicalAreaId' => '2005',
      'geographicalCode' => '1',
      'parentGeographicalAreaGroupSid' => '23802',
      'validityStartDate' => '1997-01-01T00:00:00',
      'geographicalAreaDescriptionPeriod' => [
        {
          'hjid' => '11078014',
          'metainfo' => {
            'opType' => operation,
            'origin' => 'T',
            'status' => 'L',
            'transactionDate' => '2021-01-29T18:05:33',
          },
          'sid' => '1429',
          'validityStartDate' => '2021-01-01T00:00:00',
          'geographicalAreaDescription' => {
            'hjid' => '11078015',
            'metainfo' => {
              'opType' => operation,
              'origin' => 'T',
              'status' => 'L',
              'transactionDate' => '2021-01-29T18:05:33',
            },
            'description' => '– Least Developed Countries',
            'language' => { 'hjid' => '9', 'languageId' => 'EN' },
          },
        },
      ],
      'geographicalAreaMembership' => [
        {
          'hjid' => '25624',
          'metainfo' => {
            'opType' => operation,
            'origin' => 'T',
            'status' => 'L',
            'transactionDate' => '2018-12-15T04:15:45',
          },
          'geographicalAreaGroupSid' => '23588',
          'validityStartDate' => '1997-01-01T00:00:00',
        },
      ],
      'filename' => 'foo.gzip',
    }
  end

  let(:operation) { 'U' }

  it_behaves_like 'an entity mapper', 'GeographicalArea', 'GeographicalArea' do
    let(:expected_values) do
      {
        validity_start_date: '1997-01-01T00:00:00.000Z',
        validity_end_date: nil,
        national: false,
        operation: 'U',
        operation_date: Date.parse('2021-01-29'),
        hjid: 23_937,
        geographical_area_sid: 62,
        geographical_code: '1',
        geographical_area_id: '2005',
        parent_geographical_area_group_sid: 23_802,
      }
    end
  end

  describe '#import' do
    subject(:entity_mapper) { CdsImporter::EntityMapper.new('GeographicalArea', xml_node) }

    context 'when the geographical area is being updated' do
      let(:operation) { 'U' }

      it_behaves_like 'an entity mapper update operation', GeographicalArea
      it_behaves_like 'an entity mapper update operation', GeographicalAreaMembership
      it_behaves_like 'an entity mapper update operation', GeographicalAreaDescriptionPeriod
      it_behaves_like 'an entity mapper update operation', GeographicalAreaDescription
    end

    context 'when the geographical area is being created' do
      let(:operation) { 'C' }

      it_behaves_like 'an entity mapper create operation', GeographicalArea
      it_behaves_like 'an entity mapper create operation', GeographicalAreaMembership
      it_behaves_like 'an entity mapper create operation', GeographicalAreaDescriptionPeriod
      it_behaves_like 'an entity mapper create operation', GeographicalAreaDescription
    end

    context 'when the geographical area is being deleted' do
      before do
        create(:geographical_area, geographical_area_sid: '62')
        create(:geographical_area, hjid: '23588', geographical_area_sid: '63')
        create(:geographical_area_membership, geographical_area_group_sid: '62', geographical_area_sid: '63', validity_start_date: '1997-01-01T00:00:00')
        create(:geographical_area_description, geographical_area_sid: '62', geographical_area_description_period_sid: '1429')
        create(:geographical_area_description_period, geographical_area_sid: '62', geographical_area_description_period_sid: '1429')
      end

      let(:operation) { 'D' }

      it_behaves_like 'an entity mapper destroy operation', GeographicalArea
      it_behaves_like 'an entity mapper destroy operation', GeographicalAreaMembership
      it_behaves_like 'an entity mapper destroy operation', GeographicalAreaDescriptionPeriod
      it_behaves_like 'an entity mapper destroy operation', GeographicalAreaDescription
    end
  end
end
