require 'rails_helper'

describe TradeTariffBackend::Validations::ValidityDateSpanValidation do
  describe '#valid?' do
    context 'of option provided' do
      let(:validation) { described_class.new(:vld1, 'validity_date') }

      it 'raises ArgumentError' do
        expect { validation.valid?(nil) }.to raise_error ArgumentError
      end
    end

    context 'of option not provided' do
      context 'associated records validity start date is less than models' do
        let(:model) do
          double(validity_start_date: Date.yesterday,
                 associated_record: double(validity_start_date: Date.current, new?: false))
        end
        let(:validation) { described_class.new(:vld1, 'validity_date') }

        it 'returns false' do
          expect(
            described_class.new(
              :vld1,
              'validity date span validation',
              validation_options: { of: :associated_record },
            ).valid?(model),
          ).to be_falsy
        end
      end

      context 'associated record has validity end date and model does not' do
        let(:model) do
          double(validity_start_date: Date.yesterday,
                 validity_end_date: nil,
                 associated_record: double(validity_start_date: Date.current, new?: false,
                                           validity_end_date: Date.yesterday))
        end
        let(:validation) { described_class.new(:vld1, 'validity_date') }

        it 'returns false' do
          expect(
            described_class.new(
              :vld1,
              'validity date span validation',
              validation_options: { of: :associated_record },
            ).valid?(model),
          ).to be_falsy
        end
      end

      context 'both have end dates but associated records validity end date is greater than models' do
        let(:model) do
          double(validity_start_date: Date.yesterday,
                 validity_end_date: Date.yesterday,
                 associated_record: double(validity_start_date: Date.current,
                                           validity_end_date: Date.current,
                                           new?: false))
        end
        let(:validation) { described_class.new(:vld1, 'validity_date') }

        it 'returns false' do
          expect(
            described_class.new(
              :vld1,
              'validity date span validation',
              validation_options: { of: :associated_record },
            ).valid?(model),
          ).to be_falsy
        end
      end
    end
  end
end
