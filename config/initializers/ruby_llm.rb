# OpenaiTransport configures RubyLLM for each OpenAI request. Load the model
# registry at boot, so that the first AI call in each process does not read it
# inside its own deadline.
RubyLLM.models
