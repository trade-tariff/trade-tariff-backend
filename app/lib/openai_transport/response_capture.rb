module OpenaiTransport
  # A RubyLLM instrumenter that keeps the HTTP response of the request and
  # passes every event to the configured instrumenter.
  class ResponseCapture
    attr_reader :response

    def initialize(instrumenter)
      @instrumenter = instrumenter
    end

    def instrument(name, payload, &)
      return forward(name, payload, &) unless name == 'request.ruby_llm' && block_given?

      forward(name, payload) { |*args| @response = yield(*args) }
    end

  private

    def forward(name, payload, &block)
      return block&.call(payload) unless @instrumenter.respond_to?(:instrument)

      block ? @instrumenter.instrument(name, payload, &block) : @instrumenter.instrument(name, payload)
    end
  end
end
