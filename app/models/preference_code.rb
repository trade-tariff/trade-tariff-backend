class PreferenceCode
  def initialize(id:, description:)
    @id = id
    @description = description
  end

  attr_accessor :id, :description
end
