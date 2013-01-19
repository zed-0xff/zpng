module ZPNG
  class Color
    attr_accessor :r, :g, :b
    attr_reader   :a
    attr_accessor :depth

    include DeepCopyable

    def initialize *a
      h = a.last.is_a?(Hash) ? a.pop : {}
      @r,@g,@b,@a = *a

      # default sample depth for r,g,b and alpha = 8 bits
      @depth       = h[:depth]       || 8

      # default ALPHA = 0xff - opaque
      @a ||= h[:alpha] || h[:a] || (2**@depth-1)
    end

    def a= a
      @a = a || (2**@depth-1)   # NULL alpha means fully opaque
    end
    alias :alpha  :a
    alias :alpha= :a=

    BLACK = Color.new(0  ,  0,  0)
    WHITE = Color.new(255,255,255)

    RED   = Color.new(255,  0,  0)
    GREEN = Color.new(0  ,255,  0)
    BLUE  = Color.new(0  ,  0,255)

    YELLOW= Color.new(255,255,  0)
    CYAN  = Color.new(  0,255,255)
    PURPLE= MAGENTA =
            Color.new(255,  0,255)

    TRANSPARENT = Color.new(0,0,0,0)

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

    def to_gray_alpha
      [to_grayscale, alpha]
    end

    class << self
      # from_grayscale level
      # from_grayscale level,        :depth => 16
      # from_grayscale level, alpha
      # from_grayscale level, alpha, :depth => 16
      def from_grayscale value, *args
        Color.new value,value,value, *args
      end

      # value: (String) "#ff00ff", "#f0f", "f0f", "eebbcc"
      # alpha can be set via :alpha => N optional hash argument
      def from_html value, *args
        s = value.tr('#','')
        case s.size
        when 3
          r,g,b = s.split('').map{ |x| x.to_i(16)*17 }
        when 6
          r,g,b = s.scan(/../).map{ |x| x.to_i(16) }
        else
          raise ArgumentError, "invalid HTML color #{s}"
        end
        Color.new r,g,b, *args
      end
      alias :from_css :from_html
    end

    ########################################################
    # simple conversions

    def to_i
      ((a||0) << 24) + ((r||0) << 16) + ((g||0) << 8) + (b||0)
    end

    def to_s
      "%02X%02X%02X" % [r,g,b]
    end

    def to_a
      [r, g, b, a]
    end

    ########################################################
    # complex conversions

    # try to convert to one pseudographics ASCII character
    def to_ascii map=ASCII_MAP
      #p self
      map[self.to_grayscale*(map.size-1)/(2**@depth-1), 1]
    end

    # convert to ANSI color name
    def to_ansi
      return to_depth(8).to_ansi if depth != 8
      a = ANSI_COLORS.map{|c| self.class.const_get(c.to_s.upcase) }
      a.map!{ |c| self.euclidian(c) }
      ANSI_COLORS[a.index(a.min)]
    end

    # HTML/CSS color in notation like #33aa88
    def to_css
      return to_depth(8).to_css if depth != 8
      "#%02X%02X%02X" % [r,g,b]
    end
    alias :to_html :to_css

    ########################################################

    # change bit depth, return new Color
    def to_depth new_depth
      return self if depth == new_depth

      color = Color.new :depth => new_depth
      if new_depth > self.depth
        %w'r g b a'.each do |part|
          color.send("#{part}=", (2**new_depth-1)/(2**depth-1)*self.send(part))
        end
      else
        # new_depth < self.depth
        %w'r g b a'.each do |part|
          color.send("#{part}=", self.send(part)>>(self.depth-new_depth))
        end
      end
      color
    end

    def inspect
      s = "#<ZPNG::Color"
      if depth == 16
        s << " r=" + (r ? "%04x" % r : "????")
        s << " g=" + (g ? "%04x" % g : "????")
        s << " b=" + (b ? "%04x" % b : "????")
        s << " alpha=%04x" % alpha if alpha && alpha != 0xffff
      else
        s << " #"
        s << (r ? "%02x" % r : "??")
        s << (g ? "%02x" % g : "??")
        s << (b ? "%02x" % b : "??")
        s << " alpha=%02x" % alpha if alpha && alpha != 0xff
      end
      s << " depth=#{depth}" if depth != 8
      s << ">"
    end

    # compare with other color
    def == c
      return false unless c.is_a?(Color)
      c1,c2 =
        if self.depth > c.depth
          [self, c.to_depth(self.depth)]
        else
          [self.to_depth(c.depth), c]
        end
      c1.r == c2.r && c1.g == c2.g && c1.b == c2.b && c1.a == c2.a
    end
    alias :eql? :==

    # compare with other color
    def <=> c
      c1,c2 =
        if self.depth > c.depth
          [self, c.to_depth(self.depth)]
        else
          [self.to_depth(c.depth), c]
        end
      r = c1.to_grayscale <=> c2.to_grayscale
      r == 0 ? (c1.to_a <=> c2.to_a) : r
    end

    # subtract other color from this one, returns new Color
    def - c
      op :-, c
    end

    # add other color to this one, returns new Color
    def + c
      op :+, c
    end

    # XOR this color with other one, returns new Color
    def ^ c
      op :^, c
    end

    # AND this color with other one, returns new Color
    def & c
      op :&, c
    end

    # OR this color with other one, returns new Color
    def | c
      op :|, c
    end

    # Op! op! op! Op!! Oppan Gangnam Style!!
    def op op, c=nil
      # XXX what to do with alpha?
      max = 2**depth-1
      if c
        c = c.to_depth(depth)
        Color.new(
          @r.send(op, c.r) & max,
          @g.send(op, c.g) & max,
          @b.send(op, c.b) & max,
          :depth => self.depth
        )
      else
        Color.new(
          @r.send(op) & max,
          @g.send(op) & max,
          @b.send(op) & max,
          :depth => self.depth
        )
      end
    end

    # for Array.uniq()
    def hash
      self.to_i
    end
  end
end
