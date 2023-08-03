RSpec.describe Api::V2::CertificateSearch::CertificatePresenter do
  subject(:presented) { described_class.new(certificate, goods_nomenclatures) }

  let(:certificate) { build :certificate, certificate_type_code: '9', certificate_code: '99L' }
  let(:goods_nomenclatures) { build_list :goods_nomenclature, 1, goods_nomenclature_sid: 1 }

  describe '#goods_nomenclature_ids' do
    it { expect(presented.goods_nomenclature_ids).to eq [1] }
  end

  describe '#goods_nomenclatures' do
    it { expect(presented.goods_nomenclatures).to eq goods_nomenclatures }
  end

  describe '.wrap' do
    subject(:wrapped) { described_class.wrap(certificates, grouped_goods_nomenclatures) }

    let(:certificates) { build_list :certificate, 1, certificate_type_code: '9', certificate_code: '99L' }
    let(:goods_nomenclatures) { build_list :goods_nomenclature, 1 }
    let(:grouped_goods_nomenclatures) { { '999L' => goods_nomenclatures } }

    it { expect(wrapped).to all(be_a(described_class)) }
    it { expect(wrapped.first.goods_nomenclatures).to eq goods_nomenclatures }
  end
end
