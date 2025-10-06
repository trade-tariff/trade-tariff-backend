RSpec.describe CdsImporter::ExcelWriter::GeographicalArea do
  subject(:mapper) { described_class.new(models) }

  let(:geo_area) do
    instance_double(
      GeographicalArea,
      class: instance_double(Class, name: 'GeographicalArea'),
      geographical_area_id: '3001',
      geographical_area_sid: 1,
      parent_geographical_area_group_sid: 3,
      operation: 'C',
      validity_start_date: Time.utc(2025, 1, 1, 0, 0, 0),
      validity_end_date: Time.utc(2025, 12, 31, 23, 59, 59),
    )
  end

  let(:description_period) do
    instance_double(
      GeographicalAreaDescriptionPeriod,
      class: instance_double(Class, name: 'GeographicalAreaDescriptionPeriod'),
      geographical_area_description_period_sid: 1,
      geographical_area_sid: 1,
      geographical_area_id: '3001',
      validity_start_date: Time.utc(2025, 1, 1, 0, 0, 0),
      validity_end_date: Time.utc(2025, 12, 31, 23, 59, 59),
    )
  end

  let(:description_period2) do
    instance_double(
      GeographicalAreaDescriptionPeriod,
      class: instance_double(Class, name: 'GeographicalAreaDescriptionPeriod'),
      geographical_area_description_period_sid: 2,
      geographical_area_sid: 1,
      geographical_area_id: '3001',
      validity_start_date: Time.utc(2023, 2, 2, 0, 0, 0),
      validity_end_date: Time.utc(2025, 12, 31, 23, 59, 59),
    )
  end

  let(:description) do
    instance_double(
      GeographicalAreaDescription,
      class: instance_double(Class, name: 'GeographicalAreaDescription'),
      geographical_area_description_period_sid: 1,
      geographical_area_sid: 1,
      geographical_area_id: '3001',
      description: 'Countries - export restriction protective equipment R2020/204',
    )
  end

  let(:description2) do
    instance_double(
      GeographicalAreaDescription,
      class: instance_double(Class, name: 'GeographicalAreaDescription'),
      geographical_area_description_period_sid: 2,
      geographical_area_sid: 1,
      geographical_area_id: '3001',
      description: 'Countries - export restriction protective equipment R 2020/568',
    )
  end

  let(:geo_area_membership) do
    instance_double(
      GeographicalAreaMembership,
      class: instance_double(Class, name: 'GeographicalAreaMembership'),
      geographical_area_group_sid: 4,
      geographical_area_sid: 1,
      operation: 'C',
      validity_start_date: Time.utc(2025, 1, 1, 0, 0, 0),
      validity_end_date: Time.utc(2025, 0o6, 30, 23, 59, 59),
    )
  end

  let(:geo_area_membership2) do
    instance_double(
      GeographicalAreaMembership,
      class: instance_double(Class, name: 'GeographicalAreaMembership'),
      geographical_area_group_sid: 5,
      geographical_area_sid: 1,
      operation: 'C',
      validity_start_date: Time.utc(2025, 0o7, 0o1, 0, 0, 0),
      validity_end_date: nil,
    )
  end

  describe '#data_row' do
    context 'when all fields are valid' do
      let(:models) { [geo_area, description, description_period, description2, description_period2, geo_area_membership, geo_area_membership2] }
      let!(:membership) { create(:geographical_area, :with_description, geographical_area_sid: 4) }
      let!(:membership2) { create(:geographical_area, :with_description, geographical_area_sid: 5) }

      it 'returns a correctly formatted data row' do
        row = mapper.data_row

        expect(row[0]).to eq('Create a new geographical area')
        expect(row[1]).to eq('3001')
        expect(row[2]).to eq(1)
        expect(row[3]).to eq('01/01/2025')
        expect(row[4]).to eq('31/12/2025')
        expect(row[5]).to eq("01/01/2025\nCountries - export restriction protective equipment R2020/204\n02/02/2023\nCountries - export restriction protective equipment R 2020/568\n")
        expect(row[6]).to eq("01/07/2025 : #{membership2.description}\n")
        expect(row[7]).to eq("01/01/2025 to 30/06/2025 : #{membership.description}\n01/07/2025 : #{membership2.description}\n")
        expect(row[8]).to eq(3)
      end
    end

    context 'when there is no description' do
      let(:models) { [geo_area] }

      it 'returns a correctly formatted data row' do
        row = mapper.data_row

        expect(row[0]).to eq('Create a new geographical area')
        expect(row[1]).to eq('3001')
        expect(row[2]).to eq(1)
        expect(row[3]).to eq('01/01/2025')
        expect(row[4]).to eq('31/12/2025')
        expect(row[5]).to eq('')
        expect(row[6]).to eq('')
        expect(row[7]).to eq('')
        expect(row[8]).to eq(3)
      end
    end

    context 'when there are empty fields' do
      let(:models) do
        [instance_double(
          GeographicalArea,
          class: instance_double(Class, name: 'GeographicalArea'),
          geographical_area_id: '1005',
          geographical_area_sid: 2,
          parent_geographical_area_group_sid: 3,
          operation: 'C',
          validity_start_date: nil,
          validity_end_date: nil,
        )]
      end

      it 'returns a correctly formatted data row' do
        row = mapper.data_row

        expect(row[0]).to eq('Create a new geographical area')
        expect(row[1]).to eq('1005')
        expect(row[2]).to eq(2)
        expect(row[3]).to eq('')
        expect(row[4]).to eq('')
        expect(row[5]).to eq('')
        expect(row[6]).to eq('')
        expect(row[7]).to eq('')
        expect(row[8]).to eq(3)
      end
    end
  end
end
