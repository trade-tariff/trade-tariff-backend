module SynonymsHelper
  def create_synonym_for(reference, title = 'synonym')
    create(:search_reference, title: title, referenced: reference)
  end
end
