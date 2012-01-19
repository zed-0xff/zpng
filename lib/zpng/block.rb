module ZPNG
  class Block
    attr_accessor :width, :height, :pixels
    def initialize image, x, y, w, h
      @width, @height = w,h
      @pixels = []
      h.times do |i|
        w.times do |j|
          @pixels << image[x+j,y+i]
        end
      end
    end

    def to_s
      a = []
      height.times do |i|
        b = []
        width.times do |j|
          b << pixels[i*width+j].to_s
        end
        a << b.join(" ")
      end
      a.join "\n"
    end

    def to_binary_string c_white = ' ', c_black = 'X'
      @pixels.each do |p|
        raise "pixel #{p.inspect} is not white nor black" if !p.white? && !p.black?
      end
      a = []
      height.times do |i|
        b = []
        width.times do |j|
          b << (pixels[i*width+j].black? ? c_black : c_white)
        end
        a << b.join(" ")
      end
      a.join "\n"
    end
  end
end
