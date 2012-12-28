require File.expand_path(File.join(File.dirname(__FILE__), '/spec_helper'))
require 'zpng/cli'

PNGSuite.each_good do |fname|
  describe fname.sub(%r|\A#{Regexp::escape(Dir.getwd)}/?|, '') do
    it "accessess_all_pixels" do
      img = ZPNG::Image.load(fname)
      n = 0
      img.each_pixel do |px|
        px.should be_instance_of(ZPNG::Color)
        n += 1
      end
      n.should == img.width*img.height
    end
  end
end
