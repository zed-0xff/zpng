require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

CROP_WIDTH  = 10
CROP_HEIGHT = 10
CROP_SAMPLE = File.join(SAMPLES_DIR, "captcha_4bpp.png")

include ZPNG

describe Image do
  describe "crop" do
    it "crops and keeps original image unchanged" do
      src1 = Image.load(CROP_SAMPLE)
      src2 = Image.load(CROP_SAMPLE)
      dest = src1.crop :width => CROP_WIDTH, :height => CROP_HEIGHT

      dest.width.should  == CROP_WIDTH
      dest.height.should == CROP_HEIGHT

      dest.width.should_not  == src1.width
      dest.height.should_not == src1.height

      src1.export.should == src2.export
      src1.export.should_not == dest.export
      src2.export.should_not == dest.export
    end
  end

  describe "crop! result" do
    let!(:img){
      Image.load(CROP_SAMPLE).crop! :width => CROP_WIDTH, :height => CROP_HEIGHT
    }
    it "has #{CROP_HEIGHT} scanlines" do
      img.scanlines.size.should == CROP_HEIGHT
    end

    CROP_HEIGHT.times do |i|
      it "calculates proper #size" do
        scanline_size = (img.hdr.bpp*img.width/8).ceil + 1
        img.scanlines[i].size.should == scanline_size
      end
      it "exports proper count of bytes" do
        scanline_size = (img.hdr.bpp*img.width/8).ceil + 1
        img.scanlines[i].export.size.should == scanline_size
      end
    end

    describe "reimported" do
      let!(:img2){ Image.new(img.export) }

      it "has #{CROP_HEIGHT} scanlines" do
        img2.scanlines.size.should == CROP_HEIGHT
      end
    end
  end
end
