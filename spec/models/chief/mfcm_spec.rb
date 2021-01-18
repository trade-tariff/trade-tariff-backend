require 'rails_helper'

describe Chief::Mfcm do
  let(:mfcm_attrs) { attributes_for(:mfcm).slice(:msrgp_code, :msr_type, :tty_code, :audit_tsmp) }

  describe 'associations' do
    describe 'tame' do
      let!(:mfcm) { create :mfcm, mfcm_attrs.merge(audit_tsmp: 10.years.ago) }
      let!(:tame) { create :tame, mfcm_attrs }

      context 'single choice' do
        it 'can be associated to one tame record' do
          expect(mfcm.tame).to eq tame
        end
      end

      context 'multiple choices' do
        it 'latest relevant tame record is chosen' do
          older_tame = create :tame, mfcm_attrs.merge(audit_tsmp: 20.years.ago)
          expect(mfcm.tame).to     eq tame
          expect(mfcm.tame).not_to eq older_tame
        end
      end
    end
  end

  describe '#mark_as_processed!' do
    it 'marks itself as processed' do
      mfcm = create :mfcm
      expect(mfcm.processed).to be_falsy
      mfcm.mark_as_processed!
      expect(mfcm.reload.processed).to be_truthy
    end
  end
end
