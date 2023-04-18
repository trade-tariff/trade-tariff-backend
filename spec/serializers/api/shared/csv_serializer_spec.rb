RSpec.describe Api::Shared::CsvSerializer do
  subject(:serialized) { serializer.new([data]).serialized_csv }

  let :data do
    OpenStruct.new.tap do |data|
      data.name = 'A String'
      data.age = 1
      data.date_of_birth = Date.parse('2000-01-01')
      data.is_admin = true
      data.bio = nil
      data.created_at = Time.zone.parse('2010-01-01 23:59:59.999999')
    end
  end

  let :serializer do
    Class.new do
      include Api::Shared::CsvSerializer

      columns :name, :age, :date_of_birth
      column :is_admin, column_name: 'admin'
      column :bio, column_name: 'biography'
      column :created_at
    end
  end

  describe 'header row' do
    subject { serialized.lines[0].strip.split(',') }

    it { is_expected.to have_attributes length: 6 }
    it { is_expected.to include 'name' }
    it { is_expected.to include 'age' }
    it { is_expected.to include 'date_of_birth' }
    it { is_expected.to include 'admin' }
    it { is_expected.to include 'biography' }
    it { is_expected.to include 'created_at' }
  end

  describe 'data row' do
    subject { serialized.lines[1].strip.split(',') }

    it { is_expected.to have_attributes length: 6 }
    it { is_expected.to include 'A String' }
    it { is_expected.to include '1' }
    it { is_expected.to include '2000-01-01' }
    it { is_expected.to include 'true' }
    it { is_expected.to include '' }
    it { is_expected.to include '2010-01-01 23:59:59 UTC' }
  end
end
