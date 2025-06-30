RSpec.describe GoodsNomenclatures::TreeNodeAlias do
  subject(:instance) { described_class.new :aliased_table }

  describe '#position' do
    subject { instance.position }

    it { is_expected.to be_instance_of Sequel::SQL::QualifiedIdentifier }
    it { is_expected.to have_attributes table: :aliased_table }
    it { is_expected.to have_attributes column: :position }
  end

  describe '#depth' do
    subject { instance.depth }

    it { is_expected.to be_instance_of Sequel::SQL::QualifiedIdentifier }
    it { is_expected.to have_attributes table: :aliased_table }
    it { is_expected.to have_attributes column: :depth }
  end
end
