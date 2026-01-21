NOTIFY_CONFIGURATION = if ENV['ENVIRONMENT'] == 'production'
  { # rubocop:disable Layout/IndentationWidth
    templates: {
      enquiry_form: {
        submission: '104e74e3-8f43-4642-a594-4d4ef931b121',
      },
      myott: {
        stop_press: '3295f0bf-c75f-4202-8dcf-703e4564b932',
        tariff_change: '5db33f13-7235-4ed8-b704-e3fddc01ee09',
      },
    },
    reply_to: {
      tariff_management: '61e19d5e-4fae-4b7e-aa2e-cd05a87f4cf8',
    },
  }
elsif ENV['ENVIRONMENT'] == 'staging' # rubocop:disable Layout/ElseAlignment
  {
    templates: {
      enquiry_form: {
        submission: '6033e45a-7029-4c5a-b4d3-e52ba111c9b4',
      },
      myott: {
        stop_press: '92cf170e-d9a3-4dd4-bb4d-93bbe2c547aa',
        tariff_change: '53c88c0c-69be-4375-829f-c6fbb1b9e2ef',
      },
    },
    reply_to: {
      tariff_management: 'ed4f4168-e8c5-4b80-94b9-050c86a40f0f',
    },
  }
else # development / default # rubocop:disable Layout/ElseAlignment
  {
    templates: {
      enquiry_form: {
        submission: '180f1b06-3d77-4da5-9b19-2101a74fd1b8',
      },
      myott: {
        stop_press: '41b0c946-8234-4c74-86fc-3db0beb72ecb',
        tariff_change: 'd25ab0ca-0114-47dc-954a-488516301580',
      },
    },
    reply_to: {
      tariff_management: 'e780283a-471f-42ae-a573-4364ef604fea',
    },
  }
end # rubocop:disable Layout/EndAlignment
