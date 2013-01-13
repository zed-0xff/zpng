require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

each_sample("mouse*.bmp") do |fname|
  describe fname do
    subject(:bmp){ ZPNG::Image.load(fname) }
    let!(:png){ ZPNG::Image.load(fname.sub(".bmp",".png")) }

    its(:width ){ should == png.width }
    its(:height){ should == png.height }
    its(:format){ should == :bmp }

    it "should be equal to PNG" do
      bmp.should == png
    end

    it "should restore original imagedata" do
      File.binread(fname).should include(bmp.imagedata)
    end
  end
end
