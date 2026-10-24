require File.expand_path(File.join(File.dirname(__FILE__), '/spec_helper'))
require 'zpng/cli'
require 'tempfile'
require 'tmpdir'
require 'fileutils'

describe "CLI" do
  PNGSuite.each_good do |fname|
    describe fname.sub(%r|\A#{Regexp::escape(Dir.getwd)}/?|, '') do

      it "works" do
        orig_stdout, out = $stdout, ""
        begin
          $stdout = StringIO.new(out)
          lambda { ZPNG::CLI.new([fname]).run }.should_not raise_error
        ensure
          $stdout = orig_stdout
        end
      end

      it "works verbosely" do
        orig_stdout, out = $stdout, ""
        begin
          $stdout = StringIO.new(out)
          lambda { ZPNG::CLI.new([fname, "-vvv"]).run }.should_not raise_error
        ensure
          $stdout = orig_stdout
        end
      end

      it "to ASCII" do
        orig_stdout, out = $stdout, ""
        begin
          $stdout = StringIO.new(out)
          lambda { ZPNG::CLI.new([fname, "-A"]).run }.should_not raise_error
        ensure
          $stdout = orig_stdout
        end
      end

      it "to ANSI" do
        orig_stdout, out = $stdout, ""
        begin
          $stdout = StringIO.new(out)
          lambda { ZPNG::CLI.new([fname, "-N"]).run }.should_not raise_error
        ensure
          $stdout = orig_stdout
        end
      end

      it "to ANSI256" do
        orig_stdout, out = $stdout, ""
        begin
          $stdout = StringIO.new(out)
          lambda { ZPNG::CLI.new([fname, "-2"]).run }.should_not raise_error
        ensure
          $stdout = orig_stdout
        end
      end

    end
  end

  it "cuts long metadata" do
    fname = File.join(SAMPLES_DIR, "cats.png")
    orig_stdout, out = $stdout, ""
    begin
      $stdout = StringIO.new(out)
      lambda { ZPNG::CLI.new([fname]).run }.should_not raise_error
    ensure
      $stdout = orig_stdout
    end
    out.size.should < 100_000
  end

  describe "stripping metadata" do
    def run_cli args
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

    def strip_chunks types
      %w'tEXt zTXt iTXt tIME'.each do |t|
        types.should_not include(t)
      end
    end

    it "removes text and time chunks but keeps everything else, on rebuild" do
      fname = File.join(SAMPLES_DIR, "itxt.png")
      orig = ZPNG::Image.from_file(fname)
      tempfile = Tempfile.new('zpng-strip')
      begin
        run_cli [fname, '--strip-metadata', '--rebuild', '-o', tempfile.path]
      ensure
        tempfile.close
      end
      stripped = ZPNG::Image.from_file(tempfile.path)
      types = stripped.chunks.map(&:type)
      strip_chunks types
      %w'gAMA sBIT pCAL bKGD pHYs'.each do |t|
        types.should include(t)
      end
      orig.scanlines.map(&:decoded_bytes).should == stripped.scanlines.map(&:decoded_bytes)
    end

    it "keeps unknown chunks" do
      fname = File.join(SAMPLES_DIR, "cats.png")
      tempfile = Tempfile.new('zpng-strip')
      begin
        run_cli [fname, '--strip-metadata', '--rebuild', '-o', tempfile.path]
      ensure
        tempfile.close
      end
      stripped = ZPNG::Image.from_file(tempfile.path)
      types = stripped.chunks.map(&:type)
      strip_chunks types
      types.should include('vpAg')
    end

    it "is flag-order independent" do
      fname = File.join(SAMPLES_DIR, "itxt.png")
      tempfile = Tempfile.new('zpng-strip')
      begin
        run_cli [fname, '--rebuild', '--strip-metadata', '-o', tempfile.path]
      ensure
        tempfile.close
      end
      types = ZPNG::Image.from_file(tempfile.path).chunks.map(&:type)
      strip_chunks types
      %w'gAMA sBIT pCAL bKGD pHYs'.each do |t|
        types.should include(t)
      end
    end

    it "rebuilds without stripping, keeping metadata, when only --rebuild is given" do
      fname = File.join(SAMPLES_DIR, "itxt.png")
      tempfile = Tempfile.new('zpng-rebuild')
      begin
        run_cli [fname, '--rebuild', '-o', tempfile.path]
      ensure
        tempfile.close
      end
      types = ZPNG::Image.from_file(tempfile.path).chunks.map(&:type)
      %w'tEXt zTXt iTXt'.each do |t|
        types.should include(t)
      end
    end

    it "warns and does not write when --rebuild is given without -o" do
      fname = File.join(SAMPLES_DIR, "cats.png")
      orig_stdout, orig_stderr = $stdout, $stderr
      out, err = StringIO.new, StringIO.new
      begin
        $stdout = out
        Object.send(:remove_const, :STDERR)
        Object.const_set(:STDERR, err)
        ZPNG::CLI.new([fname, '--rebuild']).run
      ensure
        $stdout = orig_stdout
        $stderr = orig_stderr
        Object.send(:remove_const, :STDERR)
        Object.const_set(:STDERR, orig_stderr)
      end
      err.string.should include("--rebuild requires -o/--out")
      out.string.should == ""
    end

    it "saves a stripped copy with -o alone, without rebuilding" do
      fname = File.join(SAMPLES_DIR, "itxt.png")
      tempfile = Tempfile.new('zpng-strip')
      begin
        out = run_cli [fname, '--strip-metadata', '-o', tempfile.path]
      ensure
        tempfile.close
      end
      stripped = ZPNG::Image.from_file(tempfile.path)
      types = stripped.chunks.map(&:type)
      strip_chunks types
      %w'gAMA sBIT pCAL bKGD pHYs'.each do |t|
        types.should include(t)
      end
      out.should include('image size')
    end

    it "treats -o as a directory, keeping the input basename" do
      fname = File.join(SAMPLES_DIR, "cats.png")
      dir = Dir.mktmpdir
      begin
        run_cli [fname, '--strip-metadata', '-o', dir]
        stripped = ZPNG::Image.from_file(File.join(dir, "cats.png"))
        types = stripped.chunks.map(&:type)
        strip_chunks types
        types.should include('vpAg')
      ensure
        FileUtils.remove_entry(dir)
      end
    end

    it "works alone" do
      fname = File.join(SAMPLES_DIR, "cats.png")
      out = run_cli [fname, '--strip-metadata']
      %w'tEXt zTXt iTXt tIME'.each do |t|
        out.should_not include(t)
      end
      out.should include('vpAg')
    end
  end
end
