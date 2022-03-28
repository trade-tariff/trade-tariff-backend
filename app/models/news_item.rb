class NewsItem < Sequel::Model
  plugin :timestamps
  plugin :auto_validations

  DISPLAY_REGULAR = 0

  dataset_module do
    def descending
      order(Sequel.desc(:start_date), Sequel.desc(:id))
    end

    def for_today
      where { start_date <= Time.zone.today }
      .where { (end_date >= Time.zone.today) | { end_date: nil } }
    end

    def for_service(service_name)
      case service_name.to_s
      when 'uk' then where(show_on_uk: true)
      when 'xi' then where(show_on_xi: true)
      else self
      end
    end

    def for_target(target_name)
      case target_name.to_s
      when 'home' then where(show_on_home_page: true)
      when 'updates' then where(show_on_updates_page: true)
      when 'banner' then where(show_on_banner: true)
      else self
      end
    end
  end

  def validate
    super

    validates_presence :title if title
    validates_presence :content if content
  end
end
