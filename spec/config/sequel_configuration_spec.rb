RSpec.describe 'Sequel configuration' do
  describe 'after_connect hook' do
    subject(:after_connect_hook) { Rails.application.config.sequel.after_connect }

    it 'configures connection validator when a DB connection is available' do
      pool = instance_double(Sequel::ThreadedConnectionPool)
      db = instance_double(Sequel::Database, pool: pool)

      allow(Sequel::Model).to receive(:plugin)
      allow(Sequel::Model).to receive(:db).and_return(db)
      allow(db).to receive(:extension)
      allow(pool).to receive(:connection_validation_timeout=)

      after_connect_hook.call

      expect(db).to have_received(:extension).with(:connection_validator)
      expect(pool).to have_received(:connection_validation_timeout=).with(60)
    end
  end

  describe 'sequel initializer' do
    it 'does not touch Sequel::Model.db during boot' do
      allow(Sequel::Model).to receive(:db).and_raise('unexpected db access')

      expect { load Rails.root.join('config/initializers/sequel.rb').to_s }.not_to raise_error
    end
  end
end
