require 'rails_helper'

describe TradeTariffBackend::DataMigration::BlockAccessor do
  let(:mock_class) do
    Class.new do
      include TradeTariffBackend::DataMigration::BlockAccessor

      block_accessor :foo
    end
  end

  describe '#foo' do
    context 'called with a block' do
      it 'sets instance value to the provided block' do
        mc = mock_class.new
        mc.foo { 'bar' }

        expect(mc.instance_variable_get(:"@foo")).to be_kind_of(Proc)
      end
    end

    context 'called without a block' do
      it 'calls preset block' do
        mc = mock_class.new
        mc.foo { 'bar' }

        expect(mc.foo).to eq 'bar'
      end
    end
  end
end
