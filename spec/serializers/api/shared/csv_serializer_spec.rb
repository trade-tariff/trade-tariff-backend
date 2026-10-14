RSpec.describe Api::Shared::CsvSerializer do
  subject(:serialized) { serializer.new([data]).serialized_csv }

  let(:csv_row_class) { Data.define(:name, :age, :date_of_birth, :is_admin, :bio, :created_at) }
  let :data do
    csv_row_class.new(
      name: 'A String',
      age: 1,
      date_of_birth: Date.parse('2000-01-01'),
      is_admin: true,
      bio: nil,
      created_at: Time.zone.parse('2010-01-01 23:59:59.999999'),
    )
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

  describe 'formula escaping' do
    subject(:row) { CSV.parse(serializer.new([data]).serialized_csv)[1] }

    let(:csv_row_class) { Data.define(:value) }
    let(:data) { csv_row_class.new(value:) }
    let(:value) { '=HYPERLINK("https://example.com")' }

    context 'when the serializer does not opt in' do
      let(:serializer) do
        Class.new do
          include Api::Shared::CsvSerializer

          column :value
        end
      end

      it { is_expected.to eq([value]) }
    end

    context 'when the serializer opts in' do
      let(:serializer) do
        Class.new do
          include Api::Shared::CsvSerializer

          escape_formulas!
          column :value
        end
      end

      it { is_expected.to eq(["'#{value}"]) }

      it 'does not escape the header row' do
        expect(CSV.parse(serializer.new([data]).serialized_csv)[0]).to eq(%w[value])
      end
    end
  end

  describe '.escape_formula' do
    {
      '=1+1' => "'=1+1",
      '+1' => "'+1",
      '-1' => "'-1",
      '@SUM(A1)' => "'@SUM(A1)",
      "\t=1+1" => "'\t=1+1",
      "\rtext" => "'\rtext",
      '  =1+1' => "'  =1+1",
      'live horses' => 'live horses',
      '0101210000 — live = horses' => '0101210000 — live = horses',
      'a-b' => 'a-b',
      '' => '',
    }.each do |input, expected|
      it "returns #{expected.inspect} for #{input.inspect}" do
        expect(described_class.escape_formula(input)).to eq(expected)
      end
    end

    it { expect(described_class.escape_formula(-5)).to eq(-5) }
    it { expect(described_class.escape_formula(nil)).to be_nil }
  end
end
