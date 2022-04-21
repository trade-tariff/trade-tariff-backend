require 'data_migrations'

RSpec.describe DataMigrations do
  before do
    allow(described_class).to receive(:migrations_dir).and_return(migrations_dir)
  end

  let(:migrations_dir) { Rails.root.join(file_fixture_path).join('data_migrations') }
  let(:note_attrs) { { section_id: '9999', content: 'Data migration test' } }
  let(:section_note) { SectionNote.where(note_attrs) }

  let :test_migration do
    Sequel::Model.db[:data_migrations]
                 .where(filename: '20220422105306_create_section_note.rb')
  end

  describe 'migrate' do
    subject(:migrate) { described_class.migrate(nil) }

    it 'runs the outstanding migration to create the chapter note' do
      expect { migrate }.to change(section_note, :count).from(0).to(1)
    end

    it 'creates the migration record in the data_migrations table' do
      migrate

      expect(test_migration.count).to be 1
    end
  end

  describe 'rollback' do
    subject :rollback do
      described_class.migrate described_class.previous_migration
    end

    before { described_class.migrate(nil) }

    it 'will revert the migration' do
      expect { rollback }.to change(section_note, :count).from(1).to(0)
    end

    it 'removes the migration record from the data_migrations_table' do
      rollback

      expect(test_migration.count).to be 0
    end
  end
end
