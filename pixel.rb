module ZPNG
  class Pixel < Struct.new(:r,:g,:b,:a)
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
