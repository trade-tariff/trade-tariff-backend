NOTIFY_CONFIGURATION =
  if ENV['ENVIRONMENT'] == 'production'
    {
      templates: {
        enquiry_form: {
          submission: '104e74e3-8f43-4642-a594-4d4ef931b121',
        },
        myott: {
          stop_press: '3295f0bf-c75f-4202-8dcf-703e4564b932',
          tariff_change: '5db33f13-7235-4ed8-b704-e3fddc01ee09',
        },
        notifications: {
          appendix5a: 'c35e387b-a2b8-4308-997c-06e1f3b36900',
          customs_tariff_update: '02da9ea8-4919-45af-a9d4-68c908f49c9c',
        },
        search_references: {
          invalidation_alert: 'a265f092-5665-4afd-b2c3-052a94f90ad0',
        },
      },
      reply_to: {
        tariff_management: '61e19d5e-4fae-4b7e-aa2e-cd05a87f4cf8',
      },
    }
  elsif ENV['ENVIRONMENT'] == 'staging'
    {
      templates: {
        enquiry_form: {
          submission: '6033e45a-7029-4c5a-b4d3-e52ba111c9b4',
        },
        myott: {
          stop_press: '92cf170e-d9a3-4dd4-bb4d-93bbe2c547aa',
          tariff_change: '53c88c0c-69be-4375-829f-c6fbb1b9e2ef',
        },
        notifications: {
          appendix5a: '943fd08f-d9f0-47e0-b9dd-40284f308414',
          customs_tariff_update: 'eae01fd6-3e73-4a21-83ed-175eec3701c5',
        },
        search_references: {
          invalidation_alert: 'fe20294b-9505-4a97-9eab-c5d5f3781bf9',
        },
      },
      reply_to: {
        tariff_management: 'ed4f4168-e8c5-4b80-94b9-050c86a40f0f',
      },
    }
  else # development / default
    {
      templates: {
        enquiry_form: {
          submission: '180f1b06-3d77-4da5-9b19-2101a74fd1b8',
        },
        myott: {
          stop_press: '41b0c946-8234-4c74-86fc-3db0beb72ecb',
          tariff_change: 'd25ab0ca-0114-47dc-954a-488516301580',
        },
        notifications: {
          appendix5a: '7b53d787-2659-4cd2-9e45-afe93ad61eec',
          customs_tariff_update: 'b99d0cef-0dce-414f-b3e2-28cf25075a43',
        },
        search_references: {
          invalidation_alert: 'f7a4a307-938c-4ce8-9ec5-e1e05df5195b',
        },
      },
      reply_to: {
        tariff_management: 'e780283a-471f-42ae-a573-4364ef604fea',
      },
    }
  end
