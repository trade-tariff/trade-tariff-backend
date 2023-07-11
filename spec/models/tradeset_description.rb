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
    subject(:tradeset_description) { described_class.new.tap(&:valid?) }

    its(:errors) { is_expected.to include(filename: ['is not present']) }
    its(:errors) { is_expected.to include(description: ['is not present']) }
    its(:errors) { is_expected.to include(goods_nomenclature_item_id: ['is not present']) }
    its(:errors) { is_expected.to include(classification_date: ['is not present']) }
    its(:errors) { is_expected.to include(created_at: ['is not present']) }
    its(:errors) { is_expected.to include(updated_at: ['is not present']) }
    its(:errors) { is_expected.to include(validity_start_date: ['is not present']) }
    its(:errors) { is_expected.not_to include(:validity_end_date) }
  end

  describe 'associations' do
    describe '#goods_nomenclature' do
      subject(:tradeset_description) do
        goods_nomenclature_item_id = '0102030405'
        create(:goods_nomenclature, goods_nomenclature_item_id:)

        described_class.new(goods_nomenclature_item_id:).tap(&:save)
      end

      its(:goods_nomenclature) { is_expected.to be_a GoodsNomenclature }
    end
  end

  describe '.build' do
    subject(:tradeset_description) { described_class.build(attributes) }

    let(:attributes) do
      {
        filename: 'filename',
        gdsdesc: 'description',
        cmdtycode: '0102030405',
        created_at: '2019-01-01T00:00:00.000Z',
        updated_at: '2019-01-01T00:00:00.000Z',
        classification_date: '2019-01-01T00:00:00.000Z',
      }
    end

    its(:filename) { is_expected.to eq 'filename' }
    its(:description) { is_expected.to eq 'description' }
    its(:goods_nomenclature_item_id) { is_expected.to eq '0102030405' }
    its(:created_at) { is_expected.to eq '2019-01-01T00:00:00.000Z' }
    its(:updated_at) { is_expected.to eq '2019-01-01T00:00:00.000Z' }
    its(:classification_date) { is_expected.to eq '2019-01-01T00:00:00.000Z' }
    its(:validity_start_date) { is_expected.to eq '2019-01-01T00:00:00.000Z' }
    its(:validity_end_date) { is_expected.to be_nil }
  end

  describe '#description_indexed' do
    subject(:tradeset_description) { described_class.new(description:) }

    let(:description) { 'input Description, other than this part' }

    its(:description_indexed) { is_expected.to eq 'input description' }
  end
end
