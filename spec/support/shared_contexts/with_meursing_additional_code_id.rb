RSpec.shared_context 'with meursing additional code id' do |meursing_additional_code_id|
  around do |example|
    TradeTariffRequest.meursing_additional_code_id = meursing_additional_code_id
    example.run
    TradeTariffRequest.meursing_additional_code_id = nil
  end
end
