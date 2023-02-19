require File.expand_path(File.join(File.dirname(__FILE__), '/spec_helper'))
require 'zpng/cli'
require 'set'

PNGSuite.each_good do |fname|
  describe fname.sub(%r|\A#{Regexp::escape(Dir.getwd)}/?|, '') do
    it "accessess all pixels" do
      img = ZPNG::Image.load(fname)
      n = 0
      img.each_pixel do |px|
        px.should be_instance_of(ZPNG::Color)
        n += 1
      end
      n.should == img.width*img.height
    end

    it "accessess all pixels with coords" do
      img = ZPNG::Image.load(fname)
      n = 0
      ax = Set.new
      ay = Set.new
      img.each_pixel do |px, x, y|
        px.should be_instance_of(ZPNG::Color)
        n += 1
        ax << x
        ay << y
      end
      n.should == img.width*img.height
      ax.size.should == img.width
      ay.size.should == img.height
    end

    it "accessess all pixels using method #2" do
      img = ZPNG::Image.load(fname)
      n = 0
      a = img.each_pixel.to_a
      ax = Set.new
      ay = Set.new
      a.each do |px, x, y|
        px.should be_instance_of(ZPNG::Color)
        n += 1
        ax << x
        ay << y
      end
      n.should == img.width*img.height
      ax.size.should == img.width
      ay.size.should == img.height
    end
  end
end
