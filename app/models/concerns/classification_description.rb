module ClassificationDescription
  extend ActiveSupport::Concern

  def descriptions_with_other_handling(description)
    collect_other_chain(description, &:formatted_description)
  end

  def raw_classification_description
    desc = description.to_s
    return desc unless is_other?(desc)

    collect_other_chain(desc) { |gn| gn.description.to_s }.join(' > ')
  end

  def is_other?(description)
    description&.match(/^other$/i)
  end

  private

  def collect_other_chain(description)
    all_other = true
    descriptions = [description]

    ancestors.reverse_each do |ancestor|
      desc = yield(ancestor)
      descriptions.unshift(desc)

      unless is_other?(desc)
        all_other = false
        break
      end
    end

    descriptions.unshift(yield(heading)) if all_other

    descriptions
  end
end
