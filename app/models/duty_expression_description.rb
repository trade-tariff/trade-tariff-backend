class DutyExpressionDescription < Sequel::Model
  plugin :oplog, primary_key: :duty_expression_id

  set_primary_key [:duty_expression_id]

  def abbreviation
    {
      '01' => '%',
      '02' => '-',
      '04' => '+',
      '12' => '+ EA',
      '14' => '+ EAR',
      '15' => 'MIN',
      '17' => 'MAX',
      '19' => '+',
      '20' => '+',
      '21' => '+ADSZ',
      '25' => '+ADSZR',
      '27' => '+ADFM',
      '29' => '+ADFMR',
      '35' => 'MAX',
      '36' => '-',
      '37' => 'NIHIL',
      '40' => 'ERCER',
      '41' => 'ERRIS',
      '42' => 'EREGG',
      '43' => 'ERSUG',
      '44' => 'ERMLK',
      '99' => 'UNSUP',
    }[duty_expression_id]
  end
end
