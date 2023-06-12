module Cache
  class CacheIndex < ::SearchIndex
    def name
      "#{super}-cache"
    end

    def dataset
      TimeMachine.now { super.actual }
    end

    def dataset_page(...)
      TimeMachine.now { super }
    end

    def page_size
      5
    end

    def hidden_codes
      @hidden_codes ||= HiddenGoodsNomenclature.codes
    end

    def serialize_record(record)
      serializer.new(record, hidden_codes).as_json
    end
  end
end
