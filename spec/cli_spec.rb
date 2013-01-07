require File.expand_path(File.join(File.dirname(__FILE__), '/spec_helper'))
require 'zpng/cli'

CLI_PATHNAME = File.expand_path(File.join(File.dirname(__FILE__), '/../bin/zpng'))

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
end
