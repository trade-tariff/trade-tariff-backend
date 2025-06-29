RSpec.describe RulesOfOrigin::OriginReferenceDocument do
  describe 'attributes' do
    it { is_expected.to respond_to :ord_title }
    it { is_expected.to respond_to :ord_version }
    it { is_expected.to respond_to :ord_date }
    it { is_expected.to respond_to :ord_original }
    it { is_expected.to respond_to :id }
  end

  describe '.new' do
    subject { build :rules_of_origin_origin_reference_document }

    it { is_expected.to have_attributes ord_title: 'Some title' }
    it { is_expected.to have_attributes ord_version: '1.1' }
    it { is_expected.to have_attributes ord_date: '28 December 2021' }
    it { is_expected.to have_attributes ord_original: '211203_ORD_Japan_V1.1.odt' }
    it { is_expected.to have_attributes id: 'aee30471c8034e951d77eedff818cdad' }
  end
end
