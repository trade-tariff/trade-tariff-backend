describe TradeTariffBackend::DataMigration::Runner do
  let(:migration) { double('Data migration', some_test_method: true) }

  let(:runner) { described_class.new(migration, :up) }

  it 'delegates undefined method calls to migration' do
    runner.some_test_method

    expect(migration).to have_received :some_test_method
  end
end
