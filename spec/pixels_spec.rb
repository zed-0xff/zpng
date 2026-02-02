require File.expand_path(File.join(File.dirname(__FILE__), '/spec_helper'))
require 'zpng/cli'
require 'tempfile'

describe "CLI pixels" do
  let(:img) do
    # Create a 2x2 RGB image with known colors
    img = ZPNG::Image.new(:width => 2, :height => 2, :bpp => 32)
    img[0, 0] = ZPNG::Color.new(255, 0, 0, 255)     # red, opaque
    img[1, 0] = ZPNG::Color.new(0, 255, 0, 255)     # green, opaque
    img[0, 1] = ZPNG::Color.new(0, 0, 255, 128)     # blue, semi-transparent
    img[1, 1] = ZPNG::Color.new(255, 255, 255, 0)   # white, fully transparent
    img
  end

  let(:tempfile) do
    file = Tempfile.new(['test', '.png'])
    img.save(file.path)
    file
  end

  after do
    tempfile.close
    tempfile.unlink
  end

  def run_cli(*args)
    orig_stdout = $stdout
    out = ""
    begin
      $stdout = StringIO.new(out)
      ZPNG::CLI.new(args).run
    ensure
      $stdout = orig_stdout
    end
    out
  end

  describe "-p / --pixels" do
    it "works with default format" do
      out = run_cli("-p", tempfile.path)
      lines = out.strip.split("\n")
      lines.size.should == 4
      lines[0].should == "0,0,ff0000ff"  # red (rgba)
      lines[1].should == "1,0,00ff00ff"  # green (rgba)
      lines[2].should == "0,1,0000ff80"  # blue (rgba, alpha=128=0x80)
      lines[3].should == "1,1,ffffff00"  # white (rgba, alpha=0)
    end

    it "works with custom hex format" do
      out = run_cli("-p%x,%y,%r,%g,%b", tempfile.path)
      lines = out.strip.split("\n")
      lines[0].should == "0,0,ff,00,00"
      lines[1].should == "1,0,00,ff,00"
      lines[2].should == "0,1,00,00,ff"
      lines[3].should == "1,1,ff,ff,ff"
    end

    it "works with decimal format" do
      out = run_cli("-p%x,%y,%R,%G,%B", tempfile.path)
      lines = out.strip.split("\n")
      lines[0].should == "0,0,255,0,0"
      lines[1].should == "1,0,0,255,0"
      lines[2].should == "0,1,0,0,255"
      lines[3].should == "1,1,255,255,255"
    end

    it "works with %argb format" do
      out = run_cli("-p%argb", tempfile.path)
      lines = out.strip.split("\n")
      lines[0].should == "ffff0000"
      lines[1].should == "ff00ff00"
      lines[2].should == "800000ff"
      lines[3].should == "00ffffff"
    end

    it "works with %rgba format" do
      out = run_cli("-p%rgba", tempfile.path)
      lines = out.strip.split("\n")
      lines[0].should == "ff0000ff"  # red + alpha=ff
      lines[1].should == "00ff00ff"  # green + alpha=ff
      lines[2].should == "0000ff80"  # blue + alpha=80
      lines[3].should == "ffffff00"  # white + alpha=00
    end

    it "works with alpha formats" do
      out = run_cli("-p%x,%y,%a,%A", tempfile.path)
      lines = out.strip.split("\n")
      lines[0].should == "0,0,ff,255"
      lines[1].should == "1,0,ff,255"
      lines[2].should == "0,1,80,128"
      lines[3].should == "1,1,00,0"
    end

    it "works with %bname" do
      out = run_cli("-p%bname:%x,%y", tempfile.path)
      bname = File.basename(tempfile.path, File.extname(tempfile.path))
      lines = out.strip.split("\n")
      lines[0].should == "#{bname}:0,0"
      lines[1].should == "#{bname}:1,0"
    end

    it "works with %fname" do
      out = run_cli("-p%fname:%x,%y", tempfile.path)
      lines = out.strip.split("\n")
      lines[0].should == "#{tempfile.path}:0,0"
      lines[1].should == "#{tempfile.path}:1,0"
    end

    it "handles %% escaping" do
      out = run_cli("-p%%x=%%X %%y=%%Y x=%x y=%y", tempfile.path)
      lines = out.strip.split("\n")
      lines[0].should == "%x=%X %y=%Y x=0 y=0"
      lines[1].should == "%x=%X %y=%Y x=1 y=0"
    end

    it "handles %%%% for literal %%" do
      out = run_cli("-p100%%%% at %x,%y", tempfile.path)
      lines = out.strip.split("\n")
      lines[0].should == "100%% at 0,0"
      lines[1].should == "100%% at 1,0"
    end

    it "handles unknown format codes as literals" do
      out = run_cli("-p%x,%y,%Z", tempfile.path)
      lines = out.strip.split("\n")
      lines[0].should == "0,0,%Z"
      lines[1].should == "1,0,%Z"
    end

    it "works with complex format" do
      out = run_cli("-ppixel(%x,%y)=rgb(%R,%G,%B) alpha=%A", tempfile.path)
      lines = out.strip.split("\n")
      lines[0].should == "pixel(0,0)=rgb(255,0,0) alpha=255"
      lines[1].should == "pixel(1,0)=rgb(0,255,0) alpha=255"
    end
  end

  describe "-n / --nontransparent-pixels" do
    it "filters out transparent pixels" do
      out = run_cli("-n", tempfile.path)
      lines = out.strip.split("\n")
      lines.size.should == 3  # only 3 non-fully-transparent pixels
      lines[0].should == "0,0,ff0000ff"  # red (rgba)
      lines[1].should == "1,0,00ff00ff"  # green (rgba)
      lines[2].should == "0,1,0000ff80"  # blue (rgba, alpha=128)
      # 1,1 is filtered (alpha=0)
    end

    it "works with custom format" do
      out = run_cli("-n%x,%y,%R,%G,%B,%A", tempfile.path)
      lines = out.strip.split("\n")
      lines.size.should == 3
      lines[0].should == "0,0,255,0,0,255"
      lines[1].should == "1,0,0,255,0,255"
      lines[2].should == "0,1,0,0,255,128"
    end
  end

  describe "multiple formats in same run" do
    it "remembers format for each action" do
      out = run_cli("-p%x,%y", "-n%R,%G,%B", tempfile.path)
      lines = out.strip.split("\n")
      # First 4 lines from -p with format %x,%y
      lines[0].should == "0,0"
      lines[1].should == "1,0"
      lines[2].should == "0,1"
      lines[3].should == "1,1"
      # Next 3 lines from -n with format %R,%G,%B
      lines[4].should == "255,0,0"
      lines[5].should == "0,255,0"
      lines[6].should == "0,0,255"
    end
  end
end
