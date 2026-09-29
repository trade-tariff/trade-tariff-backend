RSpec.describe MeasureService::CouncilRegulationUrlGenerator do
  describe '#generate' do
    {
      # Regulations keep their CELEX link. Years above 70 are 19xx.
      'R09CDEF' => 'https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A32009RCDEF',
      'R72CDEF' => 'https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A31972RCDEF',
      'R1708920' => 'https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A32017R0892',
      # Listed with an OJ citation (HMRC-2159: D0142/96)
      'D9601421' => 'https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=uriserv%3AOJ.L_.1996.035.01.0001.01.ENG',
      # Listed with a blank citation: no working link exists
      'D7807980' => nil,
      # A decision that isn't listed keeps its working CELEX link
      'D0203090' => 'https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A32002D0309',
      # Agreements, notices, TARIC notices and Joint Committee acts that aren't listed get no link
      'A7300020' => nil,
      'C0101000' => nil,
      'I2303790' => nil,
      'I9902620' => nil,
      'J2400010' => nil,
      # UK excise regulations are out of scope and keep their CELEX link
      'X1970419' => 'https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A32019X7041',
    }.each do |regulation_id, url|
      it "returns the expected link for #{regulation_id}" do
        regulation = build(:base_regulation, base_regulation_id: regulation_id)

        expect(described_class.new(regulation).generate).to eq(url)
      end
    end

    it 'keeps the CELEX link for a UK national regulation' do
      regulation = build(:base_regulation, :uk_concatenated_regulation, base_regulation_id: 'A1900160')

      expect(described_class.new(regulation).generate).to eq('https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A32019A0016')
    end
  end

  describe 'LINKS_FILE' do
    let(:rows) { CSV.read(described_class::LINKS_FILE, headers: true) }
    let(:regulation_ids) { rows.map { |row| row['regulation_id'] } }

    it 'lists only non-regulation legal bases' do
      expect(regulation_ids).to all(match(/\A[ACDIJ][0-9A-Z]{7}\z/))
    end

    it 'lists each legal base once' do
      expect(regulation_ids).to eq(regulation_ids.uniq)
    end

    it 'has a blank or well-formed OJ citation for each legal base' do
      expect(rows.map { |row| row['oj_citation'] }.compact).to all(match(/\AOJ\.[LC]_\.\d{4}\.\d{3}\.01\.\d{4}\.01\.ENG\z/))
    end
  end
end
