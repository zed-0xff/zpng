module ZPNG
  class Color < Struct.new(:r,:g,:b,:a)

    def initialize *args
      super
      self.a ||= 0xff
    end

    alias :alpha :a
    def alpha= v; self.a = v; end

    BLACK = Color.new(0  ,  0,  0, 255)
    WHITE = Color.new(255,255,255, 255)

    RED   = Color.new(255,  0,  0, 255)
    GREEN = Color.new(0  ,255,  0, 255)
    BLUE  = Color.new(0  ,  0,255, 255)

    YELLOW= Color.new(255,255,  0, 255)
    CYAN  = Color.new(  0,255,255, 255)
    PURPLE= MAGENTA =
            Color.new(255,  0,255, 255)

    ANSI_COLORS = [:black, :red, :green, :yellow, :blue, :magenta, :cyan, :white]

    #ASCII_MAP = %q_ .`,-:;~"!<+*^(LJ=?vctsxj12FuoCeyPSah5wVmXA4G9$OR0MQNW#&%@_
    #ASCII_MAP = %q_ .`,-:;~"!<+*^=VXMQNW#&%@_
    #ASCII_MAP = %q_ .,:"!*=7FZVXM#%@_
    ASCII_MAP = "        .......``,,,,---:::::;;;;~~\"\"\"\"\"!!!!!!<++*^^^(((LLJ=??vvv]ts[j1122FFuooCeyyPEah55333VVmmXA4G9$666666RRRRRR00MQQNNW####&&&&&%%%%%%%%@@@@@@@"

    # euclidian distance - http://en.wikipedia.org/wiki/Euclidean_distance
    def euclidian other_color
      r  = (self.r.to_i - other_color.r.to_i)**2
      r += (self.g.to_i - other_color.g.to_i)**2
      r += (self.b.to_i - other_color.b.to_i)**2
      Math.sqrt r
    end

    def closest_ansi_color
      a = ANSI_COLORS.map{|c| self.class.const_get(c.to_s.upcase) }
      a.map!{ |c| self.euclidian(c) }
      ANSI_COLORS[a.index(a.min)]
    end

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

    # try to convert to pseudographics
    def to_ascii map=ASCII_MAP
      map[self.to_grayscale*(map.size-1)/255, 1]
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
