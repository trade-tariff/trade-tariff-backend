RSpec.describe GenerateSelfText::EncodingArtefactSanitiser do
  describe '.call' do
    it 'returns text unchanged when no artefacts are present' do
      expect(described_class.call('Fruit juice and vegetable juice')).to eq('Fruit juice and vegetable juice')
    end

    it 'returns nil unchanged' do
      expect(described_class.call(nil)).to be_nil
    end

    it 'returns blank string unchanged' do
      expect(described_class.call('')).to eq('')
    end

    context 'with e-acute artefacts (U+00E9)' do
      it 'corrects pure9e to puree' do
        expect(described_class.call('Fruit pure9e')).to eq('Fruit puree')
      end

      it 'corrects pur0e9e variant to puree' do
        expect(described_class.call('chestnut pur0e9e/paste')).to eq('chestnut puree/paste')
      end

      it 'handles plurals' do
        expect(described_class.call('fruit pure9es and pur0e9es')).to eq('fruit purees and purees')
      end

      it 'corrects ne9glige9s to negliges' do
        expect(described_class.call('panties, ne9glige9s, bathrobes')).to eq('panties, negliges, bathrobes')
      end

      it 'corrects Penede9s to Penedes' do
        expect(described_class.call('PDO wine produced in Penede9s')).to eq('PDO wine produced in Penedes')
      end
    end

    context 'with e-grave artefacts (U+00E8)' do
      it 'corrects Gruye8re to Gruyere' do
        expect(described_class.call('mixtures of Emmentaler, Gruye8re and Appenzell')).to eq('mixtures of Emmentaler, Gruyere and Appenzell')
      end
    end

    context 'with a-tilde artefacts (U+00E3)' do
      it 'corrects De3o to Dao' do
        expect(described_class.call('PDO wine produced in De3o, Bairrada')).to eq('PDO wine produced in Dao, Bairrada')
      end
    end

    context 'with NBSP artefacts (U+00A0)' do
      it 'corrects a0mm to space-mm' do
        expect(described_class.call('width not exceeding 10250a0mm')).to eq('width not exceeding 10250 mm')
      end

      it 'corrects a0kg to space-kg' do
        expect(described_class.call('not exceeding 1a0kg')).to eq('not exceeding 1 kg')
      end
    end

    context 'with degree sign artefacts (U+00B0)' do
      it 'corrects b0C to degree-C' do
        expect(described_class.call('heat resistance 200-250 b0C')).to eq("heat resistance 200-250 \u00B0C")
      end

      it 'corrects combined a0b0C to space-degree-C' do
        expect(described_class.call('temperature >= 1370a0b0C')).to eq("temperature >= 1370 \u00B0C")
      end
    end

    context 'with micro sign artefacts (U+00B5)' do
      it 'corrects b5m to micrometre' do
        expect(described_class.call('particle size <= 25 b5m')).to eq("particle size <= 25 \u00B5m")
      end
    end

    context 'with false positive safety' do
      it 'does not modify chemical formulae' do
        expect(described_class.call('Al2O3 and Si3N4')).to eq('Al2O3 and Si3N4')
      end

      it 'does not modify refrigerant codes' do
        expect(described_class.call('HFC-43-10mee and R404a')).to eq('HFC-43-10mee and R404a')
      end

      it 'does not modify text containing 9e in other contexts' do
        expect(described_class.call('19e century trade goods')).to eq('19e century trade goods')
      end
    end
  end
end
