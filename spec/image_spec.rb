require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

NEW_IMG_WIDTH  = 20
NEW_IMG_HEIGHT = 10

describe ZPNG::Image do
  describe "new" do
    let!(:img){ ZPNG::Image.new :width => NEW_IMG_WIDTH, :height => NEW_IMG_HEIGHT }

    it "returns ZPNG::Image" do
      img.should be_instance_of(ZPNG::Image)
    end
    it "creates new image of specified size" do
      img.width.should  == NEW_IMG_WIDTH
      img.height.should == NEW_IMG_HEIGHT
    end

    describe "exported image" do
      let!(:eimg){ img.export }
      it "has PNG header" do
        eimg.should start_with(ZPNG::Image::PNG_HDR)
      end

      describe "parsed again" do
        let!(:img2){ ZPNG::Image.new(eimg) }

        it "is a ZPNG::Image" do
          img2.should be_instance_of(ZPNG::Image)
        end

        it "should be of specified size" do
          img2.width.should  == NEW_IMG_WIDTH
          img2.height.should == NEW_IMG_HEIGHT
        end

        it "should have bpp = 32" do
          img2.hdr.bpp.should == 32
        end

        it "should have 3 chunks: IHDR, IDAT, IEND" do
          img2.chunks.map(&:type).should == %w'IHDR IDAT IEND'
        end

        it "should have all pixels transparent" do
          NEW_IMG_HEIGHT.times do |y|
            NEW_IMG_WIDTH.times do |x|
              img2[x,y].should be_transparent
            end
          end
        end
      end
    end
  end
end
