class EnquiryForm::SubmissionFormatter
  CATEGORY_TAGS = {
    'classification' => 'classification',
    'api_dev_portal_support' => 'api_dev_portal_support',
    'customs_valuation' => 'customs_valuation',
    'import_duties' => 'import_duties',
    'import_duties_and_quota' => 'import_duties',
    'import_duties_and_quotas' => 'import_duties',
    'valuation' => 'customs_valuation',
    'quotas' => 'import_duties',
    'origin' => 'origin',
    'stop_press_subscription' => 'stop_press_subscriptions',
    'stop_press_and_commodity_code_watch_lists' => 'stop_press_subscriptions',
    'tariff_watch_lists' => 'stop_press_subscriptions',
    'developer_portal' => 'api_dev_portal_support',
    'other' => 'other',
  }.freeze

  CATEGORY_LABELS = {
    'classification' => 'Classification',
    'api_dev_portal_support' => 'API & Dev Portal Support',
    'customs_valuation' => 'Customs Valuation',
    'import_duties' => 'Import duties',
    'import_duties_and_quota' => 'Import duties and quotas',
    'import_duties_and_quotas' => 'Import duties and quotas',
    'valuation' => 'Valuation',
    'quotas' => 'Quotas',
    'origin' => 'Origin',
    'stop_press_subscription' => 'Stop Press Subscription',
    'stop_press_and_commodity_code_watch_lists' => 'Stop Press and commodity code watch lists',
    'tariff_watch_lists' => 'Tariff Watch Lists',
    'developer_portal' => 'API support and Developer Portal',
    'other' => 'Other',
  }.freeze

  COMMON_HEADERS = [
    'Reference',
    'Submission date',
    'Full name',
    'Company name',
    'Job title',
    'Email address',
    'What do you need help with?',
  ].freeze

  COMMON_KEYS = %i[
    reference_number
    created_at
    name
    company_name
    job_title
    email
  ].freeze

  CLASSIFICATION_FIELDS = [
    [:goods_product, 'What is the product?'],
    [:goods_made_of, 'What is it made of?'],
    [:goods_used_for, 'What is it used for?'],
    [:goods_function, 'How does it work or function?'],
    [:goods_processed, 'Has it been processed, prepared or treated in any way?'],
    [:goods_packaged, 'How is it presented or packaged?'],
    [:has_commodity_code, 'Do you already have a possible commodity code?'],
    [:commodity_code, 'Possible commodity code'],
  ].freeze

  def initialize(enquiry_form_data)
    @enquiry_form_data = enquiry_form_data.to_h.symbolize_keys
  end

  def notify_category
    CATEGORY_TAGS.fetch(enquiry_form_data[:enquiry_category].to_s, 'other')
  end

  def enquiry_description
    (enquiry_form_data[:enquiry_description].presence || classification_description).to_s
  end

  def csv_headers
    if structured_classification?
      COMMON_HEADERS + CLASSIFICATION_FIELDS.map(&:second)
    else
      COMMON_HEADERS + ['How can we help?']
    end
  end

  def csv_row
    common_values = COMMON_KEYS.map { |key| enquiry_form_data[key] } + [display_category]

    if structured_classification?
      common_values + CLASSIFICATION_FIELDS.map { |key, _label| display_value(key, enquiry_form_data[key]) }
    else
      common_values + [enquiry_form_data[:enquiry_description]]
    end
  end

  private

  attr_reader :enquiry_form_data

  def classification?
    enquiry_form_data[:enquiry_category].to_s == 'classification'
  end

  def structured_classification?
    classification? && CLASSIFICATION_FIELDS.any? { |key, _label| enquiry_form_data[key].present? }
  end

  def display_category
    category = CATEGORY_LABELS.fetch(enquiry_form_data[:enquiry_category].to_s, enquiry_form_data[:enquiry_category])

    if enquiry_form_data[:enquiry_category].to_s == 'other' && enquiry_form_data[:other_category].present?
      "#{category} - #{enquiry_form_data[:other_category]}"
    else
      category
    end
  end

  def classification_description
    return unless classification?

    answers = CLASSIFICATION_FIELDS.filter_map do |key, label|
      value = display_value(key, enquiry_form_data[key])
      next if value.blank?

      "#{label}\n#{value}"
    end

    answers.join("\n\n").presence
  end

  def display_value(key, value)
    return if value.blank?

    if key == :has_commodity_code
      {
        'yes' => 'Yes',
        'no' => 'No',
      }.fetch(value.to_s, value)
    else
      value
    end
  end
end
