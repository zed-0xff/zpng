# coding: binary
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

NEW_IMG_WIDTH  = 20
NEW_IMG_HEIGHT = 10

describe ZPNG::Image do

  shared_examples "exported image" do |bpp=32|
    let(:eimg){ img.export }
    let(:img2){ ZPNG::Image.new(eimg) }

    it "has PNG header" do
      eimg.should start_with(ZPNG::Image::PNG_HDR)
    end

    describe "parsed again" do
      it "is a ZPNG::Image" do
        img2.should be_instance_of(ZPNG::Image)
      end

      it "should be of specified size" do
        img2.width.should  == NEW_IMG_WIDTH
        img2.height.should == NEW_IMG_HEIGHT
      end

      it "should have bpp = #{bpp}" do
        img2.hdr.bpp.should == bpp
      end

      it "should have 3 chunks: IHDR, IDAT, IEND" do
        img2.chunks.map(&:type).should == %w'IHDR IDAT IEND'
      end

    end
  end

  describe ".new" do
    let(:img){ ZPNG::Image.new :width => NEW_IMG_WIDTH, :height => NEW_IMG_HEIGHT }

    it "returns ZPNG::Image" do
      img.should be_instance_of(ZPNG::Image)
    end

    it "creates new image of specified size" do
      img.width.should  == NEW_IMG_WIDTH
      img.height.should == NEW_IMG_HEIGHT
    end

    include_examples "exported image" do
      it "should have all pixels transparent" do
        NEW_IMG_HEIGHT.times do |y|
          NEW_IMG_WIDTH.times do |x|
            img2[x,y].should be_transparent
          end
        end
      end
    end

    describe "setting imagedata" do
      before do
        imagedata_size = NEW_IMG_WIDTH * NEW_IMG_HEIGHT * 4
        imagedata = "\x00" * imagedata_size
        imagedata_size.times do |i|
          imagedata.setbyte(i, i & 0xff)
        end
        img.imagedata = imagedata
      end

      include_examples "exported image" do
        it "should not have all pixels transparent" do
          skip "TBD"
          NEW_IMG_HEIGHT.times do |y|
            NEW_IMG_WIDTH.times do |x|
              img2[x,y].should_not be_transparent
            end
          end
        end
      end
    end

  end

  describe ".from_rgb" do
    before do
      data_size = NEW_IMG_WIDTH * NEW_IMG_HEIGHT * 3
      @data = "\x00" * data_size
      data_size.times do |i|
        @data.setbyte(i, i & 0xff)
      end
    end

    let(:img){ ZPNG::Image.from_rgb(@data, width: NEW_IMG_WIDTH, height: NEW_IMG_HEIGHT) }

    include_examples "exported image", 24 do
      it "should have pixels from passed data" do
        i = (0..255).cycle
        NEW_IMG_HEIGHT.times do |y|
          NEW_IMG_WIDTH.times do |x|
            img2[x,y].should == ZPNG::Color.new(i.next, i.next, i.next)
          end
        end
      end
    end
  end

  describe ".from_rgba" do
    before do
      data_size = NEW_IMG_WIDTH * NEW_IMG_HEIGHT * 4
      @data = "\x00" * data_size
      data_size.times do |i|
        @data.setbyte(i, i & 0xff)
      end
    end

    let(:img){ ZPNG::Image.from_rgba(@data, width: NEW_IMG_WIDTH, height: NEW_IMG_HEIGHT) }

    include_examples "exported image" do
      it "should have pixels from passed data" do
        i = (0..255).cycle
        NEW_IMG_HEIGHT.times do |y|
          NEW_IMG_WIDTH.times do |x|
            img2[x,y].should == ZPNG::Color.new(i.next, i.next, i.next, i.next)
          end
        end
      end
    end
  end
end
