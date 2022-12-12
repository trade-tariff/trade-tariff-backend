Sequel.migration do
  EVENT_SIDS = [
    20_178,
    20_191,
    20_198,
    20_236,
    20_246,
    20_250,
    20_271,
    20_274,
    20_278,
    20_284,
    20_293,
    20_295,
    21_140,
    21_143,
    21_152,
    21_164,
    21_167,
    21_176,
    21_179,
    21_189,
    21_191,
    21_200,
    21_203,
    21_212,
    21_215,
    21_224,
    21_227,
    21_236,
    21_239,
    21_251,
    21_260,
    21_263,
    21_272,
    21_284,
    21_296,
    21_299,
    21_309,
    21_320,
    21_323,
    21_332,
    21_335,
    21_344,
    21_356,
    21_359,
    21_368,
    21_380,
    21_392,
    21_395,
    21_404,
    21_416,
    21_419,
    21_428,
    21_431,
    21_440,
    21_443,
    21_452,
    21_455,
    21_464,
    21_467,
    21_477,
    21_479,
    21_488,
    21_491,
    21_500,
    21_503,
    21_512,
    21_515,
    21_524,
    21_527,
    21_536,
    21_539,
    21_548,
    21_551,
    21_560,
    21_572,
    21_584,
    21_596,
    21_599,
    21_608,
    21_620,
    21_623,
    21_632,
    21_644,
    21_647,
    21_656,
    21_668,
    21_680,
    21_683,
    21_692,
    21_695,
    21_704,
    21_716,
    21_719,
    21_728,
    21_731,
    21_740,
    21_743,
    21_766,
    21_770,
    21_774,
    21_778,
    21_782,
    21_786,
    21_790,
    21_794,
    21_810,
    21_814,
    21_818,
    21_822,
    23_057,
    23_059,
    23_063,
    23_067,
    23_086,
    23_092,
    23_098,
    23_104,
    23_110,
    23_116,
    23_122,
    23_128,
    23_134,
    23_140,
    23_146,
    23_152,
    23_158,
    23_164,
    23_170,
    23_176,
    23_182,
    23_188,
    23_194,
    23_200,
    23_206,
    23_212,
    23_218,
  ].freeze
  # IMPORTANT! Data migrations up block should be idempotent (reruns of up should produce the same effect)
  # they may get re-run as part of data rollbacks but the rollback (down) function of the data migration will not get invoked
  up do
    has_events_already = QuotaClosedAndTransferredEvent.where(quota_definition_sid: EVENT_SIDS).any?

    unless has_events_already
      run %{
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (20178, '2021-04-30T09:23:00', '2021-04-30', 1444634.463, 20179, 'C', current_date, 'tariff_dailyExtract_v1_20210720T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (20191, '2021-04-30T09:23:00', '2021-04-30', 12395657.696, 20192, 'C', current_date, 'tariff_dailyExtract_v1_20220411T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (20198, '2021-04-30T09:23:00', '2021-04-30', 3339342.083, 20199, 'C', current_date, 'tariff_dailyExtract_v1_20221208T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (20236, '2021-04-30T09:23:00', '2021-04-30', 61140463.919, 20237, 'C', current_date, 'tariff_dailyExtract_v1_20210726T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (20246, '2021-04-30T09:23:00', '2021-04-30', 1184497.4, 20247, 'C', current_date, 'tariff_dailyExtract_v1_20220504T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (20250, '2021-04-30T09:23:00', '2021-04-30', 2617145, 20251, 'C', current_date, 'tariff_dailyExtract_v1_20220504T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (20271, '2021-04-30T09:30:00', '2021-04-30', 1842353.52, 20272, 'C', current_date, 'tariff_dailyExtract_v1_20220411T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (20274, '2021-04-30T09:30:00', '2021-04-30', 8878978.781, 20275, 'C', current_date, 'tariff_dailyExtract_v1_20220708T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (20278, '2021-04-30T09:30:00', '2021-04-30', 3389486.3, 20279, 'C', current_date, 'tariff_dailyExtract_v1_20220412T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (20284, '2021-04-30T09:30:00', '2021-04-30', 2522674.861, 20285, 'C', current_date, 'tariff_dailyExtract_v1_20220505T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (20293, '2021-04-30T09:23:00', '2021-04-30', 471335.211, 20294, 'C', current_date, 'tariff_dailyExtract_v1_20221208T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (20295, '2021-04-30T09:23:00', '2021-04-30', 9173334.502, 20296, 'C', current_date, 'tariff_dailyExtract_v1_20220411T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21140, '2022-01-31T13:33:00', '2022-01-31', 122996577.138, 21141, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21143, '2022-10-28T13:03:00', '2022-10-28', 86055072.137, 21144, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21152, '2022-01-31T13:33:00', '2022-01-31', 159103.685, 21153, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21164, '2022-01-31T13:33:00', '2022-01-31', 7154269, 21165, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21167, '2022-10-28T16:17:00', '2022-10-28', 6607250, 21168, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21176, '2022-01-31T13:33:00', '2022-01-31', 15299126.18, 21177, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21179, '2022-10-28T16:17:00', '2022-10-28', 7256392.9, 21180, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21189, '2022-05-03T13:04:00', '2022-05-03', 2358892.145, 21190, 'C', current_date, 'tariff_dailyExtract_v1_20220503T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21191, '2022-10-28T16:17:00', '2022-10-28', 10742200.8, 21192, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21200, '2022-01-31T13:33:00', '2022-01-31', 90822736.175, 21201, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21203, '2022-10-28T16:17:00', '2022-10-28', 55623322.819, 21204, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21212, '2022-01-31T13:33:00', '2022-01-31', 3773606.777, 21213, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21215, '2022-11-15T14:02:00', '2022-11-15', 7384341.72, 21216, 'C', current_date, 'tariff_dailyExtract_v1_20221115T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21224, '2022-01-31T13:33:00', '2022-01-31', 4052331.63, 21225, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21227, '2022-10-28T16:17:00', '2022-10-28', 2192369.41, 21228, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21236, '2022-01-31T13:33:00', '2022-01-31', 2065805, 21237, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21239, '2022-10-28T16:17:00', '2022-10-28', 4536260, 21240, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21251, '2022-10-28T16:17:00', '2022-10-28', 2678440.741, 21252, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21260, '2022-01-31T13:33:00', '2022-01-31', 323021779.649, 21261, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21263, '2022-10-28T16:17:00', '2022-10-28', 178071743.202, 21264, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21272, '2022-01-31T13:33:00', '2022-01-31', 62059218.888, 21273, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21284, '2022-01-31T13:33:00', '2022-01-31', 27705497.62, 21285, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21296, '2022-01-31T13:33:00', '2022-01-31', 23449, 21297, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21299, '2022-10-28T16:17:00', '2022-10-28', 10682565, 21300, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21309, '2022-05-03T13:04:00', '2022-05-03', 2529332.206, 21310, 'C', current_date, 'tariff_dailyExtract_v1_20221208T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21320, '2022-01-31T13:33:00', '2022-01-31', 3629563.69, 21321, 'C', current_date, 'tariff_dailyExtract_v1_20221208T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21323, '2022-10-28T16:17:00', '2022-10-28', 6818018.674, 21324, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21332, '2022-01-31T13:33:00', '2022-01-31', 2078076, 21333, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21335, '2022-10-28T16:17:00', '2022-10-28', 1447302.68, 21336, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21344, '2022-01-31T13:33:00', '2022-01-31', 1640710.967, 21345, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21356, '2022-01-31T13:33:00', '2022-01-31', 17272485.252, 21357, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21359, '2022-10-28T16:17:00', '2022-10-28', 8905990.185, 21360, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21368, '2022-01-31T13:33:00', '2022-01-31', 22368335, 21369, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21380, '2022-01-31T13:33:00', '2022-01-31', 314027, 21381, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21392, '2022-01-31T13:33:00', '2022-01-31', 18599050, 21393, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21395, '2022-10-28T16:17:00', '2022-10-28', 85372280, 21396, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21404, '2022-01-31T13:33:00', '2022-01-31', 21203922, 21405, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21416, '2022-01-31T13:33:00', '2022-01-31', 924.61, 21417, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21419, '2022-10-28T16:17:00', '2022-10-28', 19176341.78, 21420, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21428, '2022-01-31T13:33:00', '2022-01-31', 16370463.106, 21429, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21431, '2022-10-28T16:17:00', '2022-10-28', 2779390.617, 21432, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21440, '2022-01-31T13:33:00', '2022-01-31', 258000, 21441, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21443, '2022-10-28T16:17:00', '2022-10-28', 133000, 21444, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21452, '2022-01-31T13:33:00', '2022-01-31', 3433103.494, 21453, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21455, '2022-10-28T16:17:00', '2022-10-28', 689992.656, 21456, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21464, '2022-01-31T13:33:00', '2022-01-31', 395713, 21465, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21467, '2022-10-28T16:17:00', '2022-10-28', 386148, 21468, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21477, '2022-05-04T20:46:00', '2022-05-04', 255769.06, 21478, 'C', current_date, 'tariff_dailyExtract_v1_20220505T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21479, '2022-10-28T16:17:00', '2022-10-28', 1214852.11, 21480, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21488, '2022-01-31T13:33:00', '2022-01-31', 2523815, 21489, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21491, '2022-10-28T16:17:00', '2022-10-28', 649430, 21492, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21500, '2022-01-31T13:33:00', '2022-01-31', 1311518.256, 21501, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21503, '2022-10-28T16:17:00', '2022-10-28', 586087.467, 21504, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21512, '2022-01-31T13:33:00', '2022-01-31', 4560854.879, 21513, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21515, '2022-10-28T16:17:00', '2022-10-28', 2590027.909, 21516, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21524, '2022-01-31T13:33:00', '2022-01-31', 197618.817, 21525, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21527, '2022-10-28T16:17:00', '2022-10-28', 480774, 21528, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21536, '2022-01-31T13:33:00', '2022-01-31', 2834482.515, 21537, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21539, '2022-10-28T16:17:00', '2022-10-28', 45784.925, 21540, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21548, '2022-01-31T13:33:00', '2022-01-31', 7818374.874, 21549, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21551, '2022-10-28T16:17:00', '2022-10-28', 5023761.681, 21552, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21560, '2022-01-31T13:33:00', '2022-01-31', 9168000, 21561, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21572, '2022-01-31T13:33:00', '2022-01-31', 4696000, 21573, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21584, '2022-01-31T13:33:00', '2022-01-31', 2234000, 21585, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21596, '2022-02-02T13:34:00', '2022-02-02', 1921057, 21597, 'C', current_date, 'tariff_dailyExtract_v1_20220202T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21599, '2022-10-28T16:17:00', '2022-10-28', 1191000, 21600, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21608, '2022-01-31T13:33:00', '2022-01-31', 3022474, 21609, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21620, '2022-01-31T13:33:00', '2022-01-31', 12554984.106, 21621, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21623, '2022-10-28T16:17:00', '2022-10-28', 12959962.141, 21624, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21632, '2022-01-31T13:33:00', '2022-01-31', 7215500, 21633, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21644, '2022-01-31T13:33:00', '2022-01-31', 8438000, 21645, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21647, '2022-10-28T16:17:00', '2022-10-28', 4409000, 21648, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21656, '2022-01-31T13:33:00', '2022-01-31', 2926985, 21657, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21668, '2022-01-31T13:33:00', '2022-01-31', 5433091.828, 21669, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21680, '2022-01-31T13:33:00', '2022-01-31', 17004887.453, 21681, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21683, '2022-10-28T16:17:00', '2022-10-28', 11117878.295, 21684, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21692, '2022-01-31T13:33:00', '2022-01-31', 4455674.486, 21693, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21695, '2022-10-28T16:17:00', '2022-10-28', 705999.475, 21696, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21704, '2022-01-31T13:33:00', '2022-01-31', 5965500, 21705, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21716, '2022-01-31T13:33:00', '2022-01-31', 5041184.768, 21717, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21719, '2022-10-28T16:17:00', '2022-10-28', 5207348.643, 21720, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21728, '2022-01-31T13:33:00', '2022-01-31', 20128983, 21729, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21731, '2022-10-28T16:17:00', '2022-10-28', 5919891.538, 21732, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21740, '2022-01-31T13:33:00', '2022-01-31', 6132969.487, 21741, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21743, '2022-10-28T16:17:00', '2022-10-28', 5934190.624, 21744, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21766, '2022-01-31T13:33:00', '2022-01-31', 51695353.103, 21767, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21770, '2022-01-31T13:33:00', '2022-01-31', 4465250.3, 21771, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21774, '2022-01-31T13:33:00', '2022-01-31', 3685679, 21775, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21778, '2022-01-31T13:33:00', '2022-01-31', 3285182, 21779, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21782, '2022-01-31T13:33:00', '2022-01-31', 3284527.325, 21783, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21786, '2022-01-31T13:33:00', '2022-01-31', 42032984.282, 21787, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21790, '2022-01-31T13:33:00', '2022-01-31', 3612318, 21791, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21794, '2022-01-31T13:33:00', '2022-01-31', 19201138.177, 21795, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21810, '2022-01-31T13:33:00', '2022-01-31', 19298231.463, 21811, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21814, '2022-01-31T13:33:00', '2022-01-31', 4979407.318, 21815, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21818, '2022-01-31T13:33:00', '2022-01-31', 94647698.675, 21819, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (21822, '2022-01-31T13:33:00', '2022-01-31', 624389, 21823, 'C', current_date, 'tariff_dailyExtract_v1_20220131T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (23057, '2022-05-03T13:04:00', '2022-05-03', 714531, 23058, 'C', current_date, 'tariff_dailyExtract_v1_20220503T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (23059, '2022-05-03T13:04:00', '2022-05-03', 277520.9, 23060, 'C', current_date, 'tariff_dailyExtract_v1_20220503T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (23063, '2022-05-03T13:04:00', '2022-05-03', 2273956.46, 23064, 'C', current_date, 'tariff_dailyExtract_v1_20221208T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (23067, '2022-05-03T13:04:00', '2022-05-03', 1534607.047, 23068, 'C', current_date, 'tariff_dailyExtract_v1_20220503T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (23086, '2022-11-15T14:02:00', '2022-11-15', 8357799.025, 23087, 'C', current_date, 'tariff_dailyExtract_v1_20221115T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (23092, '2022-11-15T14:02:00', '2022-11-15', 1456098, 23093, 'C', current_date, 'tariff_dailyExtract_v1_20221115T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (23098, '2022-10-28T16:17:00', '2022-10-28', 63903005.55, 23099, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (23104, '2022-10-28T16:17:00', '2022-10-28', 24991081.119, 23105, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (23110, '2022-10-28T16:17:00', '2022-10-28', 4258352.107, 23111, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (23116, '2022-10-28T16:17:00', '2022-10-28', 1306600, 23117, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (23122, '2022-10-28T16:17:00', '2022-10-28', 1802462, 23123, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (23128, '2022-10-28T16:17:00', '2022-10-28', 813237.28, 23129, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (23134, '2022-10-28T16:17:00', '2022-10-28', 21524572.607, 23135, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (23140, '2022-10-28T16:17:00', '2022-10-28', 5798583.22, 23141, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (23146, '2022-10-28T16:17:00', '2022-10-28', 4160317.065, 23147, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (23152, '2022-10-28T16:17:00', '2022-10-28', 3947676.197, 23153, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (23158, '2022-10-28T16:17:00', '2022-10-28', 12614509.204, 23159, 'C', current_date, 'tariff_dailyExtract_v1_20221208T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (23164, '2022-10-28T16:17:00', '2022-10-28', 66982, 23165, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (23170, '2022-10-28T16:17:00', '2022-10-28', 4631370.634, 23171, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (23176, '2022-10-28T16:17:00', '2022-10-28', 14603439.312, 23177, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (23182, '2022-10-28T16:17:00', '2022-10-28', 2981572.833, 23183, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (23188, '2022-10-28T16:17:00', '2022-10-28', 55701719.941, 23189, 'C', current_date, 'tariff_dailyExtract_v1_20221208T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (23194, '2022-10-28T16:17:00', '2022-10-28', 248726.82, 23195, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (23200, '2022-11-15T14:02:00', '2022-11-15', 7793905, 23201, 'C', current_date, 'tariff_dailyExtract_v1_20221115T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (23206, '2022-10-28T16:17:00', '2022-10-28', 2102000, 23207, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (23212, '2022-11-15T14:02:00', '2022-11-15', 1838300, 23213, 'C', current_date, 'tariff_dailyExtract_v1_20221115T235959.gzip');
        insert into quota_closed_and_transferred_events_oplog (quota_definition_sid, occurrence_timestamp, closing_date, transferred_amount, target_quota_definition_sid, operation, operation_date, filename) values (23218, '2022-10-28T16:17:00', '2022-10-28', 4647418.398, 23219, 'C', current_date, 'tariff_dailyExtract_v1_20221028T235959.gzip');
      }
    end
  end

  down do
    QuotaClosedAndTransferredEvent::Operation.where(quota_definition_sid: EVENT_SIDS).map(&:delete)
  end
end
