module ClassificationDescriptionHelper
  extend ActiveSupport::Concern
  def descriptions_with_other_handling(description)
    all_other = true
    descriptions = [description]

    ancestors.reverse_each do |ancestor|
      if is_other?(ancestor.formatted_description)
        descriptions.unshift(ancestor.formatted_description)
      else
        descriptions.unshift(ancestor.formatted_description)
        all_other = false
        break
      end
    end

    if all_other
      descriptions.unshift(heading.formatted_description)
    end

    descriptions
  end

  def is_other?(description)
    description&.match(/^other$/i)
  end
end
