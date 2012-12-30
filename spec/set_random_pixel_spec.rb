require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe ZPNG::Image do
  it "creates image" do
    img = ZPNG::Image.new :width => 16, :height => 16
    lambda {
      10.times do
        img[rand(16),rand(16)] = ZPNG::Color::BLACK
      end
      img.export
    }.should_not raise_error
  end
end
