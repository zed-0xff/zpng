require File.expand_path(File.join(File.dirname(__FILE__), '/spec_helper'))
require 'zpng/cli'

PNGSuite.each("???i*.png") do |fname|
  describe fname.sub(%r|\A#{Regexp::escape(Dir.getwd)}/?|, '') do
    it "deinterlaced should be pixel-by-pixel-identical to interlaced" do
      interlaced = ZPNG::Image.load(fname)
      deinterlaced = interlaced.deinterlace
      deinterlaced.each_pixel do |color,x,y|
        interlaced[x,y].should == color
      end
      interlaced.each_pixel do |color,x,y|
        deinterlaced[x,y].should == color
      end

      interlaced.pixels.to_a.should == deinterlaced.pixels.to_a
    end
  end
end
