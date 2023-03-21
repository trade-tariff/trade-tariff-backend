RSpec::Matchers.define :eq_pk do
  match do |actual|
    if actual.respond_to?(:map)
      actual.map(&:class) == expected.map(&:class) &&
        actual.map(&:pk) == expected.map(&:pk)
    else
      actual.instance_of?(expected.class) && actual&.pk == expected&.pk
    end
  end

  failure_message do |actual|
    if actual.respond_to?(:map)
      "expected #{model_ids(actual)} to == #{model_ids(expected)}"
    else
      "expected #{model_id(actual)} to == #{model_id(expected)}"
    end
  end

  private

  def model_id(model)
    "#{model.class}:#{model.pk}"
  end

  def model_ids(models)
    "[#{models.map(&method(:model_id)).join(', ')}]"
  end
end
