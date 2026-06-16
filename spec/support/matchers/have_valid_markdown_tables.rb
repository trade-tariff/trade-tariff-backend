RSpec::Matchers.define :have_valid_markdown_tables do
  match do |actual|
    @errors = []

    markdown_table_blocks(actual.to_s).each_with_index do |block, block_index|
      validate_markdown_table_block(block, block_index + 1)
    end

    @errors.empty?
  end

  failure_message do
    "expected markdown tables to be valid:\n#{@errors.join("\n")}"
  end

  def validate_markdown_table_block(block, block_number)
    if block.length < 2
      @errors << "table #{block_number} has #{block.length} row; expected at least a header and separator"
      return
    end

    unless markdown_table_separator?(block.second[:text])
      @errors << "table #{block_number} row #{block.second[:line_number]} is not a separator row"
    end

    expected_columns = markdown_table_cells(block.first[:text]).length
    block.each do |row|
      actual_columns = markdown_table_cells(row[:text]).length
      next if actual_columns == expected_columns

      @errors << "table #{block_number} row #{row[:line_number]} has #{actual_columns} cells; expected #{expected_columns}"
    end
  end

  def markdown_table_blocks(markdown)
    markdown.lines.map.with_index(1) { |line, line_number| { text: line.chomp, line_number: } }
      .chunk_while { |previous, current| markdown_table_line?(previous[:text]) && markdown_table_line?(current[:text]) }
      .select { |block| markdown_table_line?(block.first[:text]) }
  end

  def markdown_table_line?(line)
    line.to_s.strip.match?(/\A\|.*\|\z/)
  end

  def markdown_table_separator?(line)
    markdown_table_cells(line).all? { |cell| cell.match?(/\A:?-+:?\z/) }
  end

  def markdown_table_cells(line)
    inner = line.strip.delete_prefix('|').delete_suffix('|')
    split_unescaped_pipes(inner).map(&:strip)
  end

  def split_unescaped_pipes(text)
    cells = ['']
    escaped = false

    text.each_char do |character|
      if character == '|' && !escaped
        cells << ''
      else
        cells.last << character
      end

      escaped = character == '\\' && !escaped
      escaped = false if character != '\\'
    end

    cells
  end
end
