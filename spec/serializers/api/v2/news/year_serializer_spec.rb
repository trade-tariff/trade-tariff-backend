RSpec.describe Api::V2::News::YearSerializer do
  subject { described_class.new(2022).serializable_hash }

  describe '#serializable_hash' do
    let :expected do
      {
        data: {
          id: 2022.to_s,
          type: :news_year,
          attributes: {
            year: 2022,
          },
        },
      }
    end

    it { is_expected.to eq expected }
  end
end
