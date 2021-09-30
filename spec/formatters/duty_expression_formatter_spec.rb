RSpec.describe DutyExpressionFormatter do
  describe '.format' do
    let(:measurement_unit) do
      measurement_unit_abbreviation.measurement_unit
    end
    let(:unit) do
      measurement_unit.abbreviation(measurement_unit_qualifier: measurement_unit_qualifier)
    end
    let(:measurement_unit_abbreviation) do
      create(:measurement_unit_abbreviation, :with_measurement_unit, :include_qualifier)
    end
    let(:measurement_unit_qualifier) do
      create(:measurement_unit_qualifier, measurement_unit_qualifier_code: measurement_unit_abbreviation.measurement_unit_qualifier)
    end

    context 'when duty expression 99' do
      describe 'with qualifier' do
        it 'return the measurement unit' do
          expect(
            described_class.format(duty_expression_id: '99',
                                   measurement_unit: measurement_unit,
                                   measurement_unit_qualifier: measurement_unit_qualifier),
          ).to eq unit
        end
      end

      describe 'without qualifier' do
        let(:measurement_unit_abbreviation) do
          create(:measurement_unit_abbreviation, :with_measurement_unit)
        end
        let(:measurement_unit_qualifier) { nil }

        it 'returns unit' do
          expect(
            described_class.format(duty_expression_id: '99',
                                   measurement_unit: measurement_unit),
          ).to eq unit
        end
      end
    end

    context 'when duty expressions 12 14 37 40 41 42 43 44 21 25 27 29' do
      context 'when expression abbreviation present' do
        it 'returns duty expression abbreviation' do
          expect(
            described_class.format(duty_expression_id: '12',
                                   duty_expression_abbreviation: 'abc',
                                   duty_expression_description: 'def'),
          ).to eq 'abc'
        end
      end

      context 'when expression abbreviation missing' do
        it 'returns duty expression description' do
          expect(
            described_class.format(duty_expression_id: '12',
                                   duty_expression_description: 'def'),
          ).to eq 'def'
        end
      end
    end

    context 'when duty expressions 15 17 19 20' do
      context 'when expression abbreviation present' do
        it 'result includes duty expression abbreviation' do
          expect(
            described_class.format(duty_expression_id: '15',
                                   duty_expression_abbreviation: 'def'),
          ).to match(/def/)
        end
      end

      context 'when expression abbreviation missing' do
        it 'result includes duty expression abbreviation' do
          expect(
            described_class.format(duty_expression_id: '15',
                                   duty_expression_description: 'abc'),
          ).to match(/abc/)
        end
      end

      context 'when monetary unit present' do
        it 'result includes monetary unit' do
          expect(
            described_class.format(duty_expression_id: '15',
                                   duty_expression_description: 'abc',
                                   monetary_unit: 'EUR'),
          ).to match(/EUR/)
        end
      end

      context 'when monetary unit missing' do
        it 'result includes percent sign' do
          expect(
            described_class.format(duty_expression_id: '15',
                                   duty_expression_description: 'abc'),
          ).to match(/%/)
        end
      end

      context 'when measurement unit and measurement unit qualifier present' do
        it 'result includes measurement unit and measurement unit qualifier' do
          expect(
            described_class.format(duty_expression_id: '15',
                                   measurement_unit: measurement_unit,
                                   measurement_unit_qualifier: measurement_unit_qualifier,
                                   duty_expression_description: 'abc'),
          ).to match Regexp.new(unit)
        end
      end

      context 'when just measurement unit present' do
        let(:measurement_unit_abbreviation) do
          create(:measurement_unit_abbreviation, :with_measurement_unit)
        end
        let(:measurement_unit_qualifier) { nil }

        it 'result includes measurement unit' do
          expect(
            described_class.format(duty_expression_id: '15',
                                   measurement_unit: measurement_unit,
                                   duty_expression_description: 'abc'),
          ).to match Regexp.new(unit)
        end
      end
    end

    context 'when all other duty expression types' do
      context 'when amount present' do
        it 'result includes duty amount' do
          expect(described_class.format(duty_expression_id: '66',
                                        duty_expression_description: 'abc',
                                        duty_amount: '55')).to match(/55/)
        end
      end

      context 'when expression abbreviation present and monetary unit missing' do
        it 'result includes duty expression abbreviation' do
          expect(
            described_class.format(duty_expression_id: '66',
                                   duty_expression_abbreviation: 'abc',
                                   duty_amount: '55'),
          ).to match(/abc/)
        end
      end

      context 'when expression description present and monetary unit missing' do
        it 'result includes duty expression abbreviation' do
          expect(
            described_class.format(duty_expression_id: '66',
                                   duty_expression_description: 'abc',
                                   duty_amount: '55'),
          ).to match(/abc/)
        end
      end

      context 'when expression description missing' do
        it 'result includes duty expression abbreviation' do
          expect(
            described_class.format(duty_expression_id: '66',
                                   duty_amount: '55'),
          ).to match(/%/)
        end
      end

      context 'when monetary unit present' do
        let(:options) do
          {
            duty_amount: 0.52,
            duty_expression_id: '66',
            duty_expression_description: 'abc',
            monetary_unit: 'EUR',
            formatted: formatted,
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

      context 'when measurement unit and measurement unit qualifier present' do
        it 'result includes measurement unit and measurement unit qualifier' do
          expect(
            described_class.format(duty_expression_id: '66',
                                   measurement_unit: measurement_unit,
                                   measurement_unit_qualifier: measurement_unit_qualifier,
                                   duty_expression_description: 'abc'),
          ).to match Regexp.new(unit)
        end
      end

      context 'when measurement unit present' do
        let(:measurement_unit_abbreviation) do
          create(:measurement_unit_abbreviation, :with_measurement_unit)
        end
        let(:measurement_unit_qualifier) { nil }

        it 'result includes measurement unit' do
          expect(
            described_class.format(duty_expression_id: '66',
                                   measurement_unit: measurement_unit,
                                   duty_expression_description: 'abc'),
          ).to match Regexp.new(unit)
        end
      end
    end

    context 'when resolved_meursing is `true`' do
      it 'returns a formatted result surrounded by strong tags' do
        formatted = described_class.format(
          duty_expression_id: '04',
          duty_amount: 100,
          duty_expression_abbreviation: '+',
          formatted: true,
        )

        expect(formatted).to eq('+ <span>100.00</span> %')
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
