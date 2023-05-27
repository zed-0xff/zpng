require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

ROTATE_SAMPLE = File.join(SAMPLES_DIR, "captcha_4bpp.png")

include ZPNG

describe Image do
  describe "#rotated_90_cw" do
    it "rotates and keeps original image unchanged" do
      src = Image.load(ROTATE_SAMPLE)
      src2 = Image.load(ROTATE_SAMPLE)
      dst = src.rotated_90_cw

      dst.width.should  == src.height
      dst.height.should == src.width

      dst.width.should_not  == src.width
      dst.height.should_not == src.height

      src.export.should == src2.export
      src.export.should_not == dst.export
      src2.export.should_not == dst.export

      dst.export.should == File.binread(File.join(SAMPLES_DIR, "captcha_4bpp_rotated90.png"))
    end
  end
end
