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

describe "pixels enumerator" do
  describe "#uniq" do
    it "returns only unique pixels" do
      fname = File.join(SAMPLES_DIR, "qr_bw.png")
      img = ZPNG::Image.load(fname)
      a = img.pixels.uniq
      a.size.should == 2
      a.sort.should == [ZPNG::Color::BLACK, ZPNG::Color::WHITE].sort
    end
  end
end
