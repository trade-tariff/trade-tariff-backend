Rails.application.config.x.openai_model_pricing = Rails.application
  .config_for(:openai_model_pricing)
  .to_h
  .deep_stringify_keys
  .freeze
