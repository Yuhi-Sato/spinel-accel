# Port of Spinel benchmark/bm_json_parse.rb.
# run(iterations) parses the two test documents, then parses the first one
# `iterations` times, and returns the printed lines joined with "\n".
# Deviation from original: the returned string is built as "" + ... so it is
# UTF-8 in Ruby too (parse returns Integer#to_s, which CRuby tags US-ASCII
# while Spinel returns UTF-8).
module JsonParseKernel
  # Minimal JSON parser (numbers, strings, arrays, objects)
  class JSONParser
    def initialize(input)
      @input = input
      @pos = 0
    end

    def parse
      skip_ws
      parse_value
    end

    def skip_ws
      while @pos < @input.length
        c = @input[@pos]
        if c == " " || c == "\n" || c == "\t" || c == "\r"
          @pos = @pos + 1
        else
          break
        end
      end
    end

    def peek
      if @pos < @input.length
        @input[@pos]
      else
        ""
      end
    end

    def advance
      c = @input[@pos]
      @pos = @pos + 1
      c
    end

    def parse_value
      skip_ws
      c = peek
      if c == "\""
        return parse_string
      end
      if c == "["
        return parse_array
      end
      if c == "{"
        return parse_object
      end
      if c == "t"
        @pos = @pos + 4
        return "true"
      end
      if c == "f"
        @pos = @pos + 5
        return "false"
      end
      if c == "n"
        @pos = @pos + 4
        return "null"
      end
      parse_number
    end

    def parse_string
      advance  # skip "
      result = ""
      while peek != "\""
        result = result + advance
      end
      advance  # skip "
      result
    end

    def parse_number
      start = @pos
      if peek == "-"
        @pos = @pos + 1
      end
      while @pos < @input.length
        c = @input[@pos]
        if c >= "0" && c <= "9"
          @pos = @pos + 1
        elsif c == "."
          @pos = @pos + 1
        else
          break
        end
      end
      @input[start, @pos - start]
    end

    def parse_array
      advance  # skip [
      items = 0
      skip_ws
      if peek != "]"
        parse_value
        items = items + 1
        skip_ws
        while peek == ","
          advance
          parse_value
          items = items + 1
          skip_ws
        end
      end
      advance  # skip ]
      items.to_s
    end

    def parse_object
      advance  # skip {
      keys = 0
      skip_ws
      if peek != "}"
        parse_string
        skip_ws
        advance  # skip :
        parse_value
        keys = keys + 1
        skip_ws
        while peek == ","
          advance
          skip_ws
          parse_string
          skip_ws
          advance  # skip :
          parse_value
          keys = keys + 1
          skip_ws
        end
      end
      advance  # skip }
      keys.to_s
    end
  end

  def self.run(iterations)
    json = '{"name": "spinel", "version": 1, "features": ["aot", "gc", "fiber"], "fast": true}'
    parser = JSONParser.new(json)
    result = parser.parse

    json2 = '[1, 2, [3, 4, [5]], "hello", null, true, false]'
    parser2 = JSONParser.new(json2)
    result2 = parser2.parse

    i = 0
    while i < iterations
      p = JSONParser.new(json)
      p.parse
      i = i + 1
    end
    # Start from a UTF-8 literal: Integer#to_s is US-ASCII in Ruby, UTF-8 in Spinel.
    "" + result + "\n" + result2 + "\n" + "done"
  end
end
