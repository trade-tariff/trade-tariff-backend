RSpec.describe ApplicableAdditionalCodeService do
  subject(:service) { described_class.new(measures) }

  describe '#call' do
    context 'when the measures have additional codes' do
      let(:measures) do
        measure = create(
          :measure,
          :with_additional_code,
          :with_measure_type,
          measure_type_id: '105',
          additional_code_type_id: '2',
          additional_code_id: '550',
        )
        duplicate_measure = create(
          :measure,
          :with_additional_code,
          :with_measure_type,
          measure_type_id: '105',
          additional_code_type_id: '2',
          additional_code_id: '550',
          measure_sid: measure.measure_sid,
        )
        measure_with_same_measure_and_code_type = create(
          :measure,
          :with_additional_code,
          :with_measure_type,
          measure_type_id: '105',
          additional_code_type_id: '2',
          additional_code_id: '551',
        )
        measure_with_different_measure_and_code_type = create(
          :measure,
          :with_additional_code,
          :with_measure_type,
          measure_type_id: '103',
          additional_code_type_id: '8',
        )
        measure_without_additional_code = create(
          :measure,
          :with_measure_type,
          measure_type_id: '103',
        )
        [
          measure,
          duplicate_measure,
          measure_with_same_measure_and_code_type,
          measure_with_different_measure_and_code_type,
          measure_without_additional_code,
        ]
      end
      let(:expected_additional_codes) do
        {
          '105' => {
            'measure_type_description' => be_present,
            'heading' => {
              'overlay' => be_present,
              'hint' => be_present,
            },
            'additional_codes' => [
              {
                'code' => '2550',
                'overlay' => be_present,
                'hint' => '',
                'measure_sid' => be_a(Integer),
              },
              {
                'code' => '2551',
                'overlay' => be_present,
                'hint' => '',
                'measure_sid' => be_a(Integer),
              },
            ],
          },
          '103' => {
            'measure_type_description' => be_present,
            'heading' => {
              'overlay' => be_present,
              'hint' => be_present,
            },
            'additional_codes' => [
              {
                'code' => be_present,
                'overlay' => be_present,
                'hint' => '',
                'measure_sid' => be_a(Integer),
              },
              {
                'code' => 'none',
                'overlay' => 'Select no additional code',
                'hint' => '',
                'measure_sid' => be_a(Integer),
              },
            ],
          },
        }
      end

      it { expect(service.call).to include_json(expected_additional_codes) }
    end

    context 'when the measures do not have applicable additional codes' do
      let(:measures) { [measure] }
      let(:measure) do
        create(
          :measure,
          :with_additional_code,
          measure_type_id: '105',
          additional_code_type_id: 'Z',
        )
      end

      it { expect(service.call).to eq({}) }
    end
  end
end
