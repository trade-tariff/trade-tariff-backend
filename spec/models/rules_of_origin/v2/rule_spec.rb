require 'rails_helper'

RSpec.describe RulesOfOrigin::V2::Rule do
  it { is_expected.to respond_to :rule }
  it { is_expected.to respond_to :original }
  it { is_expected.to respond_to :rule_class }
  it { is_expected.to respond_to :operator }
end
