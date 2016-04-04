require 'core_ext/string'
require 'stringio'
require 'terminal-table'

module CucumberLint
  # A linter for a series of table rows (as parsed by Gherkin)
  class TableLinter < Linter

    def initialize rows:, config:, linted_file:
      super config: config, linted_file: linted_file

      @rows = rows
      @header_style = @config.consistent_table_headers.enforced_style.to_sym
    end


    def lint
      inconsistent_table_whitespace unless actual_table_lines == expected_table_lines
      inconsistent_table_headers if inconsistent_table_headers?
    end


    private


    def inconsistent_table_headers
      return unless @config.consistent_table_headers.enabled

      add_error(
        fix: -> (line) { line.split('|', -1).map(&@header_style).join('|') },
        line_number: @rows[0].location.line,
        message: "#{@header_style} table headers"
      )
    end


    def inconsistent_table_headers?
      headers = actual_table_lines[0].split('|')
      headers != headers.map(&@header_style)
    end


    def actual_table_lines
      @actual_table_lines ||= determine_actual_table_lines
    end


    def inconsistent_table_whitespace
      return unless @config.consistent_table_whitespace.enabled

      fixes = @rows.each_with_index.map do |row, index|
        { fix: -> (line) { line.gsub(/\|.*\|/, expected_table_lines[index]) },
          line_number: row.location.line }
      end

      add_error(
        fixes: fixes,
        line_number: @rows[0].location.line,
        message: 'Fix table whitespace'
      )
    end


    def determine_actual_table_lines
      @rows.map { |row| @linted_file.lines[row.location.line - 1].strip }
    end


    def determine_expected_table_lines
      @rows.each { |row| row.comments = [] }

      table = Terminal::Table.new style: { border_x: '', border_i: '' }
      table.rows = @rows.map { |row| row.cells.map(&:value) }
      table.to_s.strip.split("\n")
    end


    def expected_table_lines
      @expected_table_lines ||= determine_expected_table_lines
    end

  end
end
