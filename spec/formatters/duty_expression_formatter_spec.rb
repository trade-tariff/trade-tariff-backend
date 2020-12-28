require 'rails_helper'
require 'duty_expression_formatter'

describe DutyExpressionFormatter do
  describe '.format' do
    let(:measurement_unit) {
      measurement_unit_abbreviation.measurement_unit
    }
    let(:unit) {
      measurement_unit.abbreviation(measurement_unit_qualifier: measurement_unit_qualifier)
    }
    let!(:measurement_unit_abbreviation) {
      create(:measurement_unit_abbreviation, :with_measurement_unit, :include_qualifier)
    }
    let!(:measurement_unit_qualifier) {
      create(:measurement_unit_qualifier, measurement_unit_qualifier_code: measurement_unit_abbreviation.measurement_unit_qualifier)
    }

    context 'for excise measure' do
      it 'does not fetch exchange rates' do
        expect(MonetaryExchangePeriod).not_to receive(:actual)
        expect(MonetaryExchangeRate).not_to receive(:last)
        described_class.format(duty_expression_id: '99',
                                       measurement_unit: measurement_unit,
                                       measurement_unit_qualifier: measurement_unit_qualifier,
                                       excise: true)
      end
    end

    context 'for duty expression 99' do
      describe "with qualifier" do
        it 'return the measurement unit' do
          expect(
            described_class.format(duty_expression_id: '99',
                                           measurement_unit: measurement_unit,
                                           measurement_unit_qualifier: measurement_unit_qualifier)
          ).to eq unit
        end
      end

      describe "without qualifier" do
        let!(:measurement_unit_abbreviation) {
          create(:measurement_unit_abbreviation, :with_measurement_unit)
        }
        let(:measurement_unit_qualifier) { nil }

        it "returns unit" do
          expect(
            described_class.format(duty_expression_id: "99",
                                           measurement_unit: measurement_unit)
          ).to eq unit
        end
      end
    end

    context 'for duty expressions 12 14 37 40 41 42 43 44 21 25 27 29' do
      context 'duty expression abbreviation present' do
        it 'returns duty expression abbreviation' do
          expect(
            described_class.format(duty_expression_id: '12',
                                           duty_expression_abbreviation: 'abc',
                                           duty_expression_description: 'def')
          ).to eq 'abc'
        end
      end

      context 'duty expression abbreviation missing' do
        it 'returns duty expression description' do
          expect(
            described_class.format(duty_expression_id: '12',
                                           duty_expression_description: 'def')
          ).to eq 'def'
        end
      end
    end

    context 'for duty expressions 15 17 19 20' do
      context 'duty expression abbreviation present' do
        it 'result includes duty expression abbreviation' do
          expect(
            described_class.format(duty_expression_id: '15',
                                           duty_expression_abbreviation: 'def')
          ).to match /def/
        end
      end

      context 'duty expression abbreviation missing' do
        it 'result includes duty expression abbreviation' do
          expect(
            described_class.format(duty_expression_id: '15',
                                           duty_expression_description: 'abc')
          ).to match /abc/
        end
      end

      context 'monetary unit present' do
        it 'result includes monetary unit' do
          expect(
            described_class.format(duty_expression_id: '15',
                                           duty_expression_description: 'abc',
                                           monetary_unit: 'EUR')
          ).to match /EUR/
        end
      end

      context 'monetary unit missing' do
        it 'result includes percent sign' do
          expect(
            described_class.format(duty_expression_id: '15',
                                           duty_expression_description: 'abc')
          ).to match /%/
        end
      end

      context 'measurement unit and measurement unit qualifier present' do
        it 'result includes measurement unit and measurement unit qualifier' do
          expect(
            described_class.format(duty_expression_id: '15',
                                           measurement_unit: measurement_unit,
                                           measurement_unit_qualifier: measurement_unit_qualifier,
                                           duty_expression_description: 'abc')
          ).to match Regexp.new(unit)
        end
      end

      context 'just measurement unit present' do
        let!(:measurement_unit_abbreviation) {
          create(:measurement_unit_abbreviation, :with_measurement_unit)
        }
        let(:measurement_unit_qualifier) { nil }

        it 'result includes measurement unit' do
          expect(
            described_class.format(duty_expression_id: '15',
                                           measurement_unit: measurement_unit,
                                           duty_expression_description: 'abc')
          ).to match Regexp.new(unit)
        end
      end
    end

    context 'for all other duty expression types' do
      context 'duty amount present' do
        it 'result includes duty amount' do
          expect( described_class.format(duty_expression_id: '66',
                                           duty_expression_description: 'abc',
                                           duty_amount: '55')
          ).to match /55/
        end
      end

      context 'duty expression abbreviation present and monetary unit missing' do
        it 'result includes duty expression abbreviation' do
          expect(
            described_class.format(duty_expression_id: '66',
                                           duty_expression_abbreviation: 'abc',
                                           duty_amount: '55')
          ).to match /abc/
        end
      end

      context 'duty expression description present and monetary unit missing' do
        it 'result includes duty expression abbreviation' do
          expect(
            described_class.format(duty_expression_id: '66',
                                           duty_expression_description: 'abc',
                                           duty_amount: '55')
          ).to match /abc/
        end
      end

      context 'duty expression description missing' do
        it 'result includes duty expression abbreviation' do
          expect(
            described_class.format(duty_expression_id: '66',
                                           duty_amount: '55')
          ).to match /%/
        end
      end

      context 'monetary unit present' do
        let(:options) do
          {
            duty_amount: 0.52,
            duty_expression_id: '66',
            duty_expression_description: 'abc',
            monetary_unit: 'EUR',
            formatted: formatted
          }
        end

        context 'when formatted is `true`' do
          let(:formatted) { true }

          it 'result includes monetary unit' do
            expect(described_class.format(options)).to eq('<span>0.52</span> EUR')
          end
        end

        context 'when not formatted is `false`' do
          let(:formatted) { false }

          it 'result includes monetary unit' do
            expect(described_class.format(options)).to eq('0.52 EUR')
          end
        end
      end

      context 'measurement unit and measurement unit qualifier present' do
        it 'result includes measurement unit and measurement unit qualifier' do
          expect(
            described_class.format(duty_expression_id: '66',
                                           measurement_unit: measurement_unit,
                                           measurement_unit_qualifier: measurement_unit_qualifier,
                                           duty_expression_description: 'abc')
          ).to match Regexp.new(unit)
        end
      end

      context 'measurement unit present' do
        let!(:measurement_unit_abbreviation) {
          create(:measurement_unit_abbreviation, :with_measurement_unit)
        }
        let(:measurement_unit_qualifier) { nil }

        it 'result includes measurement unit' do
          expect(
            described_class.format(duty_expression_id: '66',
                                           measurement_unit: measurement_unit,
                                           duty_expression_description: 'abc')
          ).to match Regexp.new(unit)
        end
      end
    end
  end

  describe '.prettify' do
    context 'has less than 4 decimal places' do
      it 'returns number with insignificant zeros stripped up to 2 decimal points' do
        expect(described_class.prettify(1.2)).to eq '1.20'
      end
    end

    context 'has 4 or more decimal places' do
      it 'returns formatted number with 4 decimal places' do
        expect(described_class.prettify(1.23456)).to eq '1.2346'
      end
    end
  end
end
