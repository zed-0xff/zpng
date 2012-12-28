module ZPNG
  class Color
    attr_accessor :r, :g, :b, :a
    attr_accessor :depth

    include DeepCopyable

    def initialize *a
      h = a.last.is_a?(Hash) ? a.pop : {}
      @r,@g,@b,@a = *a

      # default sample depth for r,g,b and alpha = 8 bits
      @depth       = h[:depth]       || 8

      # default ALPHA = 0xff - opaque
      @a ||= h[:alpha] || (2**@depth-1)
    end

    alias :alpha :a
    def alpha= a; @a=a; end

    BLACK = Color.new(0  ,  0,  0)
    WHITE = Color.new(255,255,255)

    RED   = Color.new(255,  0,  0)
    GREEN = Color.new(0  ,255,  0)
    BLUE  = Color.new(0  ,  0,255)

    YELLOW= Color.new(255,255,  0)
    CYAN  = Color.new(  0,255,255)
    PURPLE= MAGENTA =
            Color.new(255,  0,255)

    ANSI_COLORS = [:black, :red, :green, :yellow, :blue, :magenta, :cyan, :white]

    #ASCII_MAP = %q_ .`,-:;~"!<+*^(LJ=?vctsxj12FuoCeyPSah5wVmXA4G9$OR0MQNW#&%@_
    #ASCII_MAP = %q_ .`,-:;~"!<+*^=VXMQNW#&%@_
    #ASCII_MAP = %q_ .,:"!*=7FZVXM#%@_

    # see misc/gen_ascii_map.rb
    ASCII_MAP =
      ["        '''''''```,,",
       ",,---:::::;;;;~~\"\"\"\"",
       "\"!!!!!!<++*^^^(((LLJ",
       "=??vvv]ts[j1122FFuoo",
       "CeyyPEah55333VVmmXA4",
       "G9$666666RRRRRR00MQQ",
       "NNW####&&&&&%%%%%%%%",
       "@@@@@@@"].join

    # euclidian distance - http://en.wikipedia.org/wiki/Euclidean_distance
    def euclidian other_color
      # TODO: different depths
      r  = (self.r.to_i - other_color.r.to_i)**2
      r += (self.g.to_i - other_color.g.to_i)**2
      r += (self.b.to_i - other_color.b.to_i)**2
      Math.sqrt r
    end

    def white?
      max = 2**depth-1
      r == max && g == max && b == max
    end

    def black?
      r == 0 && g == 0 && b == 0
    end

    def transparent?
      a == 0
    end

    def opaque?
      a.nil? || a == 2**depth-1
    end

    def to_grayscale
      (r+g+b)/3
    end

    # from_grayscale level
    # from_grayscale level,        :depth => 16
    # from_grayscale level, alpha
    # from_grayscale level, alpha, :depth => 16
    def self.from_grayscale value, *args
      Color.new value,value,value, *args
    end

    def to_s
      "%02X%02X%02X" % [r,g,b]
    end

    ########################################################

    # try to convert to pseudographics
    def to_ascii map=ASCII_MAP
      #p self
      map[self.to_grayscale*(map.size-1)/(2**@depth-1), 1]
    end

    def to_ansi
      return to_depth(8).to_ansi if depth != 8
      a = ANSI_COLORS.map{|c| self.class.const_get(c.to_s.upcase) }
      a.map!{ |c| self.euclidian(c) }
      ANSI_COLORS[a.index(a.min)]
    end

    def to_css
      return to_depth(8).to_css if depth != 8
      "#%02X%02X%02X" % [r,g,b]
    end
    alias :to_html :to_css

    ########################################################

    def to_i
      ((a||0) << 24) + ((r||0) << 16) + ((g||0) << 8) + (b||0)
    end

    # change bit depth, return new Color
    def to_depth new_depth
      c = Color.new :depth => new_depth
      if new_depth > self.depth
        %w'r g b'.each do |part|
          color = self.send(part)
          if color%2 == 0
            color <<= (new_depth-self.depth)
          else
            (new_depth-self.depth).times{ color = color*2 + 1 }
          end
          c.send("#{part}=", color)
        end
      else
        # new_depth < self.depth
        %w'r g b'.each do |part|
          c.send("#{part}=", self.send(part)>>(self.depth-new_depth))
        end
      end
      c
    end

    def inspect
      s = "#<ZPNG::Color"
      if depth == 16
        s << " r=" + (r ? "%04x" % r : "????")
        s << " g=" + (g ? "%04x" % g : "????")
        s << " b=" + (b ? "%04x" % b : "????")
        s << " alpha=%04x" % alpha if alpha
      else
        s << " #"
        s << (r ? "%02x" % r : "??")
        s << (g ? "%02x" % g : "??")
        s << (b ? "%02x" % b : "??")
        s << " alpha=%02x" % alpha if alpha
      end
      s << " depth=#{depth}" if depth != 8
      s << ">"
    end

    # compare with other color
    def == c
      depth == c.depth && r == c.r && g == c.g && b == c.b && a == c.a
    end
  end
end
