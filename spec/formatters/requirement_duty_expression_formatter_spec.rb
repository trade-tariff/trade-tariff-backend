RSpec.describe RequirementDutyExpressionFormatter do
  describe '.format' do
    let(:measurement_unit) do
      measurement_unit_abbreviation.measurement_unit
    end
    let(:unit) do
      measurement_unit.abbreviation(measurement_unit_qualifier:)
    end
    let!(:measurement_unit_abbreviation) do
      create(:measurement_unit_abbreviation, :with_measurement_unit, :include_qualifier)
    end
    let!(:measurement_unit_qualifier) do
      create(:measurement_unit_qualifier, measurement_unit_qualifier_code: measurement_unit_abbreviation.measurement_unit_qualifier)
    end

    context 'when duty amount present' do
      it 'result includes duty amount' do
        expect(
          described_class.format(duty_amount: '55'),
        ).to match(/55/)
      end
    end

    context 'when monetary unit, measurement unit & measurement_unit_qualifier are present' do
      subject(:output) do
        described_class.format(measurement_unit:,
                               formatted_measurement_unit_qualifier: 'L',
                               monetary_unit: 'EUR')
      end

      it 'properly formats output' do
        expect(output).to match(/EUR \/ \(#{measurement_unit.description} \/ L\)/)
      end
    end

    context 'when monetary unit and measurement unit are present' do
      subject(:output) do
        described_class.format(
          duty_amount: 3.50,
          monetary_unit: 'EUR',
          measurement_unit:,
          formatted:,
        )
      end

      let(:formatted) { false }

      it 'does not check the currency' do
        allow(TradeTariffBackend).to receive(:currency)

        output

        expect(TradeTariffBackend).not_to have_received(:currency)
      end

      it 'properly formats result' do
        expect(output).to eq("3.50 EUR / #{measurement_unit.description}")
      end

      context 'when formatted in html' do
        let(:formatted) { true }

        it 'properly formats result' do
          expect(output).to eq("<span>3.50</span> EUR / <abbr title='#{measurement_unit.description}'>#{measurement_unit.description}</abbr>")
        end
      end
    end

    context 'when monetary unit is present' do
      subject(:output) do
        described_class.format(
          duty_amount: 3.50,
          monetary_unit: 'EUR',
          formatted:,
        )
      end

      let(:formatted) { false }

      it 'does not check the currency' do
        allow(TradeTariffBackend).to receive(:currency)

        output

        expect(TradeTariffBackend).not_to have_received(:currency)
      end

      it 'properly formats result' do
        expect(output).to eq('3.50 EUR')
      end

      context 'when formatted in html' do
        let(:formatted) { true }

        it 'properly formats result' do
          expect(output).to eq('<span>3.50</span> EUR')
        end
      end
    end

    context 'when measurement unit is present' do
      subject(:output) do
        described_class.format(measurement_unit:)
      end

      it 'properly formats output' do
        expect(output).to match Regexp.new(measurement_unit.description)
      end
    end
  end

  describe '.prettify' do
    context 'when has less than 4 decimal places' do
      it 'returns number with insignificant zeros stripped up to 2 decimal points' do
        expect(described_class.prettify(1.2)).to eq '1.20'
      end
    end

    context 'when has 4 or more decimal places' do
      it 'returns formatted number with 4 decimal places' do
        expect(described_class.prettify(1.23456)).to eq '1.2346'
      end
    end
  end
end
