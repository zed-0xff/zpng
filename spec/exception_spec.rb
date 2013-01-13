require 'spec_helper'

describe ZPNG::Image do
  it "should raise ZPNG::NotSupported on unknown file" do
    lambda{
      ZPNG::Image.load(__FILE__)
    }.should raise_error(ZPNG::NotSupported)
  end
end
