require 'active_support/all'
require 'json'
require 'tmpdir'

VAT_GUIDANCE_POC_ROOT = Pathname.new(File.expand_path('../..', __dir__)) unless defined?(VAT_GUIDANCE_POC_ROOT)

%w[
  question_journey_contract
  question_journey_artifact_builder
  answer_path_enumerator
  tariff_snapshot_contract
  review_decision_contract
  spike_tariff_snapshot_refresher
  spike_review_fixture
  commodity_journey_composer
  hmrc_poc_artifact_builder
  hmrc_poc_renderer
  hmrc_poc_artifact_writer
].each do |service|
  require VAT_GUIDANCE_POC_ROOT.join("app/services/vat_guidance/#{service}")
end
