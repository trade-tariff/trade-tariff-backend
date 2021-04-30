require 'rails_helper'
require 'rspec/json_expectations'

describe ApplicableAdditionalCodeService do
  subject(:service) { described_class.new(measures) }

  describe '#call' do
    context 'when the measures have additional codes' do
      let(:measures) do
        [
          measure,
          measure_with_same_measure_and_code_type,
          measure_with_different_measure_and_code_type,
          measure_without_additional_code,
        ]
      end
      let(:measure) do
        create(
          :measure,
          :with_additional_code,
          measure_type_id: '105',
          additional_code_type_id: '2',
          additional_code: '550',
        )
      end
      let(:measure_with_same_measure_and_code_type) do
        create(
          :measure,
          :with_additional_code,
          measure_type_id: '105',
          additional_code_type_id: '2',
          additional_code: '551',
        )
      end
      let(:measure_with_different_measure_and_code_type) do
        create(
          :measure,
          :with_additional_code,
          measure_type_id: '103',
          additional_code_type_id: '8',
        )
      end
      let(:measure_without_additional_code) do
        create(:measure, measure_type_id: '103')
      end

      let(:expected_additional_codes) do
        {
          '105' => {
            'heading' => {
              'overlay' => 'Describe your goods in more detail',
              'hint' => 'To trade this commodity, you need to specify an additional 4 digits, known as an additional code',
            },
            'additional_codes' => [
              {
                'code' => '2550',
                'overlay' => 'Imported by sea and arriving via the Atlantic Ocean or the Suez canal with the port of unloading on the Mediterranean Sea or on the Black Sea',
                'hint' => '',
                'measure_sid' => measure.measure_sid,
              },
              {
                'code' => '2551',
                'overlay' => 'Imported by sea and arriving via the Atlantic Ocean or the Suez canal with the port of unloading on the Mediterranean Sea or on the Black Sea',
                'hint' => '',
                'measure_sid' => measure_with_same_measure_and_code_type.measure_sid,
              },
            ],
          },
          '103' => {
            'heading' => {
              'overlay' => 'From which company are you buying these goods?',
              'hint' => 'Additional duties are levied against imports from certain companies in the form of anti-dumping or anti-subsidy duties.',
            },
            'additional_codes' => [
              {
                'code' => match(/\A8.{3}\z/),
                'overlay' => be_a(String),
                'hint' => be_empty,
                'measure_sid' => measure_with_different_measure_and_code_type.measure_sid,
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
          additional_code_type_id: 'X',
        )
      end

      it { expect(service.call).to eq({}) }
    end
  end
end
