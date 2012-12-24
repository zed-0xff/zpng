require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe ZPNG::Metadata do
  # itxt.png contains all possible text chunks
  describe "itxt.png" do
    let!(:metadata){
      ZPNG::Image.load( File.join(SAMPLES_DIR, "itxt.png") ).metadata
    }
    it "should get all values" do
      metadata.size.should == 4
    end
    it "should not find not existing value" do
      metadata['foobar'].should be_nil
    end
    it "should find all existing values" do
      metadata['Title'].should == "PNG"
      metadata['Author'].should == "La plume de ma tante"
      metadata['Warning'].should == "Es is verboten, um diese Datei in das GIF-Bildformat\numzuwandeln.  Sie sind gevarnt worden."
      metadata['Description'].should =~ /Since POV-Ray does not direclty support/
    end
  end
end
