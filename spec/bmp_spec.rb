require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

each_sample("mouse.bmp") do |fname|
  describe fname do
    subject(:image){ ZPNG::Image.load(fname) }

    its(:width ){ should == 32 }
    its(:height){ should == 32 }

    it "should be equal to PNG" do
      image.should == ZPNG::Image.load(fname.sub(".bmp",".png"))
    end
  end
end
