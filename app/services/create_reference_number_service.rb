class CreateReferenceNumberService
  LENGTH = 8
  CHARSET = ('A'..'Z').to_a + (0..9).to_a.map(&:to_s) - %w[O I]

  def call
    CHARSET.sample(LENGTH).join
  end
end
