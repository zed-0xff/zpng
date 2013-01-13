module ZPNG
  class Pixels
    include Enumerable

    module ImageEnum
      def each
        @image.height.times do |y|
          @image.width.times do |x|
            yield @image[x,y]
          end
        end
      end
    end

    module ScanLineEnum
      def each
        @scanline.width.times do |x|
          yield @scanline[x]
        end
      end
    end

    def initialize x
      case x
      when Image
        @image = x
        extend ImageEnum
      when ScanLine
        @scanline = x
        extend ScanLineEnum
      else raise ArgumentError, "don't know how to enumerate #{x.inspect}"
      end
    end

    def == other
      self.to_a == other.to_a
    end

    def uniq
      self.to_a.uniq
    end
  end
end
