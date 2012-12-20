module ZPNG
  class Color < Struct.new(:r,:g,:b,:a)

    def initialize *args
      super
      self.a ||= 0xff
    end

    alias :alpha :a
    def alpha= v; self.a = v; end

    BLACK = Color.new(0,0,0,0xff)
    WHITE = Color.new(0xff,0xff,0xff,0xff)

    def white?
      r == 0xff && g == 0xff && b == 0xff
    end

    def black?
      r == 0 && g == 0 && b == 0
    end

    def transparent?
      a == 0
    end

    def to_grayscale
      (r+g+b)/3
    end

    def self.from_grayscale value, alpha = nil
      Color.new value,value,value, alpha
    end

    def to_s
      "%02X%02X%02X" % [r,g,b]
    end

    def to_i
      ((a||0) << 24) + ((r||0) << 16) + ((g||0) << 8) + (b||0)
    end

    def inspect
      if r && g && b && a
        "#<ZPNG::Color #%02x%02x%02x a=%d>" % [r,g,b,a]
      else
        rs = r ? "%02x" % r : "??"
        gs = g ? "%02x" % g : "??"
        bs = b ? "%02x" % b : "??"
        if a
          # alpha is non-NULL
          "#<ZPNG::Color #%s%s%s a=%d>" % [rs,gs,bs,a]
        else
          # alpha is NULL
          "#<ZPNG::Color #%s%s%s>" % [rs,gs,bs]
        end
      end
    end
  end
end
