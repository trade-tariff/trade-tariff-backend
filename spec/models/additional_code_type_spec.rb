describe AdditionalCodeType do
  describe '#export_refund_agricultural?' do
    let!(:ern_agricultural) { create :additional_code_type, :ern_agricultural }
    let!(:non_ern_agricultural) { create :additional_code_type, application_code: '1' }

    it 'returns true for ern_agricultural (code 4)' do
      expect(ern_agricultural).to be_export_refund_agricultural
    end

    it 'returns false for other' do
      expect(non_ern_agricultural).not_to be_export_refund_agricultural
    end
  end

  describe '#export_refund?' do
    let!(:ern) { create :additional_code_type, :ern }
    let!(:non_ern) { create :additional_code_type, application_code: '1' }

    it 'returns true for ern (code 0)' do
      expect(ern).to be_export_refund
    end

    it 'returns false for other' do
      expect(non_ern).not_to be_export_refund
    end
  end

  describe '#meursing?' do
    let!(:meursing) { create :additional_code_type, :meursing }
    let!(:non_meursing) { create :additional_code_type, application_code: '1' }

    it 'returns true for meursing (code 3)' do
      expect(meursing).to be_meursing
    end

    it 'returns false for other' do
      expect(non_meursing).not_to be_meursing
    end
  end
end
