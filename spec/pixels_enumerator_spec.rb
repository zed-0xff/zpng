require File.expand_path(File.join(File.dirname(__FILE__), '/spec_helper'))
require 'zpng/cli'

PNGSuite.each_good do |fname|
  describe fname.sub(%r|\A#{Regexp::escape(Dir.getwd)}/?|, '') do
    it "accessess all pixels via enumerator" do
      img = ZPNG::Image.load(fname)

      first_pixel = img.pixels.first

      n = 0
      img.pixels.each do |px|
        px.should be_instance_of(ZPNG::Color)
        if n == 0
          px.should == first_pixel
        end
        n += 1
      end
      n.should == img.width*img.height
    end
  end
end
