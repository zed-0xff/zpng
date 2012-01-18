module ZPNG
  class Pixel
    attr_accessor :r, :g, :b, :a
    def initialize s, g=nil, b=nil
      if s.is_a?(String) && s.size == 3
        @r = s[0].ord
        @g = s[1].ord
        @b = s[2].ord
      elsif s.is_a?(String) && s.size == 4
        @r = s[0].ord
        @g = s[1].ord
        @b = s[2].ord
        @a = s[3].ord
      elsif g && b
        @r = s & 0xff
        @g = g & 0xff
        @b = b & 0xff
      else
        raise "unknown pixel initializer: #{s.inspect}"
      end
    end

    def white?
      to_s == "FFFFFF"
    end

    def black?
      to_s == "000000"
    end

    def to_s
      "%02X%02X%02X" % [r,g,b]
    end
  end
end
