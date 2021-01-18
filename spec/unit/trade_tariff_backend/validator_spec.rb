require 'rails_helper'

describe TradeTariffBackend::Validator do
  let(:model) { double(operation: :create, conformance_errors: double(add: true)) }
  let(:generic_validator) do
    Class.new(TradeTariffBackend::Validator) do
      validation :verify1, 'some validation' do |_record|
        true
      end
    end
  end

  describe '.validations' do
    context 'no validations defined' do
      let(:validator) { Class.new(TradeTariffBackend::Validator) }

      it 'defaults to empty array' do
        expect(validator.validations).to eq []
      end
    end

    context 'some validations defined' do
      it 'returns list of defined Validations' do
        expect(generic_validator.validations).not_to be_blank
        expect(generic_validator.validations.first).to be_kind_of TradeTariffBackend::Validations::GenericValidation
      end
    end
  end

  describe '#validations' do
    it 'is an alias to class .validations method' do
      expect(generic_validator.validations).to eq generic_validator.new.validations
    end
  end

  describe '.validate' do
    before do
      generic_validator.validation :vld1, 'failing validation' do |_record|
        false
      end

      generic_validator.new.validate(model)
    end

    it 'runs validations on record' do
      expect(model.conformance_errors).to have_received(:add)
    end
  end

  describe '#validate' do
    context 'all validations pass' do
      before { generic_validator.new.validate(model) }

      it 'adds no error to object errors hash' do
        expect(model.conformance_errors).not_to have_received(:add)
      end
    end

    context 'one of the validations wont pass' do
      before do
        generic_validator.validation :vld1, 'failing validation' do |_record|
          false
        end

        generic_validator.new.validate(model)
      end

      it 'adds error to object errors hash' do
        expect(model.conformance_errors).to have_received(:add)
      end
    end
  end

  describe '#validate_for_operations' do
    let(:model) do
      double(operation: :create,
             conformance_errors: double(add: true))
    end

    let(:contextual_validator) do
      Class.new(TradeTariffBackend::Validator) do
        validation :verify1, 'some validation', on: %i[create update] do |_record|
          true
        end

        validation :verify2, 'some validation', on: [:update] do |_record|
          false
        end
      end
    end

    context 'operations match some defined validations' do
      context 'all validations pass' do
        before { contextual_validator.new.validate_for_operations(model, :create) }

        it 'adds no error to object errors hash' do
          expect(model.conformance_errors).not_to have_received(:add)
        end
      end

      context 'one of the validations wont pass' do
        before do
          contextual_validator.new.validate_for_operations(model, :create, :update)
        end

        it 'adds an error to object errors hash' do
          expect(model.conformance_errors).to have_received(:add)
        end
      end
    end

    context 'operatios do not match any validations' do
      let(:contextual_validator) do
        Class.new(TradeTariffBackend::Validator) do
          validation :verify1, 'some validation', on: %i[create update] do |_record|
            true
          end
        end
      end

      before { contextual_validator.new.validate_for_operations(model, :destroy) }

      it 'adds no errors to objects hash' do
        expect(model.conformance_errors).not_to have_received(:add)
      end
    end
  end
end
