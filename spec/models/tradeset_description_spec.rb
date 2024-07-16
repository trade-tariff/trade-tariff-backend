RSpec.describe TradesetDescription do
  describe 'attributes' do
    it { is_expected.to respond_to :filename }
    it { is_expected.to respond_to :description }
    it { is_expected.to respond_to :goods_nomenclature_item_id }
    it { is_expected.to respond_to :classification_date }
    it { is_expected.to respond_to :created_at }
    it { is_expected.to respond_to :updated_at }
    it { is_expected.to respond_to :validity_start_date }
    it { is_expected.to respond_to :validity_end_date }
  end

  describe 'validations' do
    subject(:errors) { described_class.new.tap(&:valid?).errors }

    it { is_expected.to include('filename' => ['is not present']) }
    it { is_expected.to include('description' => ['is not present']) }
    it { is_expected.to include('goods_nomenclature_item_id' => ['is not present']) }
    it { is_expected.to include('classification_date' => ['is not present']) }
    it { is_expected.to include('created_at' => ['is not present']) }
    it { is_expected.to include('updated_at' => ['is not present']) }
    it { is_expected.to include('validity_start_date' => ['is not present']) }
  end

  describe '.build' do
    subject(:tradeset_description) { described_class.build(values) }

    let(:values) do
      {
        filename: 'filename',
        gdsdesc: 'description',
        cmdtycode: '0102030405',
        created_at: '2019-01-01T00:00:00.000Z',
        updated_at: '2019-01-01T00:00:00.000Z',
        classification_date: '2019-01-01T00:00:00.000Z',
      }
    end

    it { is_expected.to be_a described_class }
    it { expect(tradeset_description.filename).to eq 'filename' }
    it { expect(tradeset_description.description).to eq 'description' }
    it { expect(tradeset_description.goods_nomenclature_item_id).to eq '0102030405' }
    it { expect(tradeset_description.created_at).to eq Time.zone.parse('2019-01-01T00:00:00.000Z') }
    it { expect(tradeset_description.updated_at).to eq Time.zone.parse('2019-01-01T00:00:00.000Z') }
    it { expect(tradeset_description.classification_date).to eq Time.zone.parse('2019-01-01T00:00:00.000Z') }
    it { expect(tradeset_description.validity_start_date).to eq Time.zone.parse('2019-01-01T00:00:00.000Z') }
    it { expect(tradeset_description.validity_end_date).to be_nil }
  end

  describe '#description_indexed' do
    subject(:tradeset_description) { described_class.new(description:).description_indexed }

    let(:description) { 'input Description, other than this part' }

    it { is_expected.to eq 'input description' }
  end
end
