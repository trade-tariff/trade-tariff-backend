class NewsItem < Sequel::Model
  plugin :timestamps
  plugin :auto_validations

  DISPLAY_REGULAR = 0

  dataset_module do
    def descending
      order(Sequel.desc(:id))
    end
  end

  def validate
    super

    validates_presence :title if title
    validates_presence :content if content
  end
end
