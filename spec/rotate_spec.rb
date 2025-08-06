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

      dst.should == Image.load(File.join(SAMPLES_DIR, "captcha_4bpp_rotated90.png"))
    end
  end

  describe "#rotated" do
    0.step(360, 90) do |angle|
      it "rotates #{angle} degrees and keeps original image unchanged" do
        src = Image.load(ROTATE_SAMPLE)
        src2 = Image.load(ROTATE_SAMPLE)
        dst = src.rotated(angle)
        dst.save("#{angle}.png")

        if angle % 180 == 0
          dst.width.should  == src.width
          dst.height.should == src.height
        else
          dst.width.should  == src.height
          dst.height.should == src.width

          dst.width.should_not  == src.width
          dst.height.should_not == src.height
        end

        src.export.should == src2.export

        if angle % 360 == 0
          src.export == dst.export
          src2.export == dst.export
        else
          src.export.should_not == dst.export
          src2.export.should_not == dst.export
        end

        src = Image.load(angle % 360 == 0 ? ROTATE_SAMPLE : File.join(SAMPLES_DIR, "captcha_4bpp_rotated#{angle}.png"))
        dst.should == src
      end
    end
  end
end
