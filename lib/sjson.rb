# frozen_string_literal: true

require 'stringio'

require_relative "sjson/version"

# Sjson handles JSON streams and ensures a complete JSON object has been read
# before returning it to the caller, ensuring it is minimally sane for parsing
class Sjson
  class ParseError < StandardError; end

  PFALSE        = :p_false
  PTRUE         = :p_true
  PNULL         = :p_null
  PSTRING       = :p_string
  POBJECT       = :p_object
  PARRAY        = :p_array
  PNUMBER       = :p_number
  POBJECT_KEY   = :p_object_key
  POBJECT_VALUE = :p_object_value

  QUOTE = '"'
  LEFT_CURLY = "{"
  RIGHT_CURLY = "}"
  LEFT_SQUARED = "["
  RIGHT_SQUARED = "]"
  MINUS = "-"
  PLUS = "+"
  DOT = "."
  NEWLINE = "\n"
  CARRIAGE_RETURN = "\r"
  TAB = "\t"
  SPACE = " "
  COMMA = ","
  COLON = ":"
  E_DOWN = "e"
  E_UP = "E"
  WSP_CHARS = [SPACE, NEWLINE, CARRIAGE_RETURN, TAB].freeze

  def initialize
    @data = StringIO.new
    @stack = []
  end

  def reset
    @data.truncate(0)
    @data.rewind
    @stack.clear
  end

  def feed_all(s)
    s.each_char do |chr|
      res = feed(chr)
      return res if res
    end
  end

  def feed(c)
    return parse_value(c) if @stack.empty?

    catch(:break_loop) do
      loop do
        catch(:retry) do
          fail! "unexpected character '#{c}', as the parser state is not ready to handle it" if @stack.empty?

          case state.first
          when PFALSE
            parse_false(c)
          when PTRUE
            parse_true(c)
          when PNULL
            parse_null(c)
          when PNUMBER
            parse_number(c)
          when PSTRING
            parse_string(c)
          when PARRAY
            parse_array(c)
          when POBJECT
            parse_object(c)
          when POBJECT_KEY
            parse_object_key(c)
          when POBJECT_VALUE
            parse_object_value(c)
          else
            # :nocov:
            fail! "BUG: Unexpected parser state #{state.first}"
            # :nocov:
          end

          throw :break_loop
        end
      end
    end

    return @data.string.dup if @stack.empty?

    nil
  end
  alias << feed

  private

  def wsp?(chr)
    WSP_CHARS.include?(chr)
  end

  def push_state(state)
    @stack << [state, @data.length - 1]
  end

  def state
    @stack.last
  end

  def fail!(why)
    raise(ParseError, "#{why} at position #{@data.length - 1}")
  end

  def pop_state
    @stack.pop
  end

  def replace_state(new)
    pop_state
    push_state(new)
  end

  def retry!
    pop_state
    throw :retry
  end

  def append(c)
    @data.write(c)
    nil
  end

  def prev_rel_byte
    return 0x00 if @data.length.zero? || @data.length - 1 < state.last

    data_at @data.length - 1
  end

  def prev_byte
    return 0x00 if @data.length.zero?

    data_at @data.length - 1
  end

  def data_at(idx)
    return 0x00 if idx >= @data.length

    @data.seek(idx, IO::SEEK_SET)
    @data.getc.tap { @data.seek(0, IO::SEEK_END) }
  end

  def data_from(idx)
    @data.seek(idx, IO::SEEK_SET)
    @data.read.tap { @data.seek(0, IO::SEEK_END) }
  end

  def handle_word_parsing(word, c)
    idx = @data.length - state.last

    fail! "expected #{word[idx]} (reading '#{word}'), found '#{c} instead" if c != word[idx]

    append(c)

    pop_state if idx == word.length - 1
  end

  def parse_false(c)
    handle_word_parsing("false", c)
  end

  def parse_true(c)
    handle_word_parsing("true", c)
  end

  def parse_null(c)
    handle_word_parsing("null", c)
  end

  def parse_string(c)
    prev_rel = prev_rel_byte
    append(c)
    pop_state if c == QUOTE && prev_rel != "\\"
  end

  def parse_array(c)
    return if wsp?(c)

    prev_rel = prev_rel_byte

    if c == RIGHT_SQUARED && prev_rel != COMMA
      append(c)
      pop_state
      return
    elsif c == COMMA && prev_rel != LEFT_SQUARED && prev_rel != COMMA
      append(c)
      return
    end

    return parse_value(c) if [LEFT_SQUARED, COMMA].include?(prev_rel)

    fail! "expected ',', found `#{c}' instead"
  end

  def parse_object(c)
    if c == RIGHT_CURLY
      append(c)
      pop_state
      return
    end

    push_state POBJECT_KEY
    throw :retry
  end

  def parse_object_key(c)
    return if wsp?(c)

    prev = prev_byte
    if c != QUOTE && prev != QUOTE
      fail! "expected '\"', found `#{c}"
    elsif c == QUOTE && prev != QUOTE
      append(c)
      push_state PSTRING
      return nil
    end

    fail! "expected ':', found #{c}" if c != COLON

    append(c)
    replace_state POBJECT_VALUE
    nil
  end

  def parse_object_value(c)
    return if wsp?(c)

    prev_rel = prev_rel_byte
    retry! if prev_rel != COLON && c == RIGHT_CURLY

    if prev_rel != COLON && c == COMMA
      append(c)
      replace_state POBJECT_KEY
      return nil
    end

    return parse_value(c) if prev_rel == COLON

    fail! "unexpected `#{c}'"
  end

  def parse_value(c)
    return if wsp?(c)

    append(c)

    case c
    when "t"
      push_state(PTRUE)
    when "f"
      push_state(PFALSE)
    when "n"
      push_state(PNULL)
    when QUOTE
      push_state(PSTRING)
    when LEFT_CURLY
      push_state(POBJECT)
    when LEFT_SQUARED
      push_state(PARRAY)
    else
      if c == MINUS || (c >= "0" && c <= "9")
        push_state(PNUMBER)
        return
      end

      fail! "expected t, f, n, \", {, [, -, or a number from 0-9, got `#{c}'"
    end

    nil
  end

  def parse_number(c)
    prev_rel = prev_rel_byte
    prev_parse = data_from(state.last)

    case c
    when MINUS
      fail! "unexpected '-'" unless [0x00, E_DOWN, E_UP].include? prev_rel
      return append(c)
    when PLUS
      fail! "unexpected '+'" unless [E_DOWN, E_UP].include? prev_rel
      return append(c)
    when DOT
      fail! "unexpected '.'" if [DOT, E_DOWN, E_UP].any? { prev_parse.include? _1 } || prev_rel == MINUS
      return append(c)
    when E_DOWN, E_UP
      fail! "unexpected '#{c}', expected a number" if prev_rel < "0" || prev_rel > "9"
      return append(c)
    when RIGHT_SQUARED, RIGHT_CURLY, COMMA, CARRIAGE_RETURN, NEWLINE, SPACE, TAB
      fail! "unexpected '#{c}', expected a number" if [E_DOWN, E_UP, PLUS, MINUS, DOT].include?(prev_rel)
      retry!
    end

    fail! "unexpected '#{c}'" if c < "0" || c > "9"

    fail! "invalid number format" if ["-0", "0"].include?(prev_parse)

    append(c)
  end
end
