module PNGSuite
  PNG_SUITE_URL = "http://www.schaik.com/pngsuite/PngSuite-2011apr25.tgz"

  class << self
    attr_accessor :dir

    def init dir
      @dir = dir
      if Dir.exist?(dir)
        if Dir[File.join(dir, "*.png")].size > 100
          # already fetched and unpacked
          return
        end
      else
        Dir.mkdir(dir)
      end
      require 'open-uri'
      puts "[.] fetching PNG test-suite from #{PNG_SUITE_URL} .. "
      data = open(PNG_SUITE_URL).read

      fname = File.join(dir, "png_suite.tgz")
      File.open(fname, "wb"){ |f| f<<data }
      puts "[.] unpacking .. "
      system "tar", "xzf", fname, "-C", dir
    end

    def each *prefixes
      Dir[File.join(dir,"*.png")].each do |fname|
        if prefixes.empty?
          yield fname
        elsif prefixes.any?{ |p| p[/[*?\[]/] ? File.fnmatch(p, File.basename(fname)) : File.basename(fname).start_with?(p) }
          yield fname
        end
      end
    end

    def each_good
      Dir[File.join(dir,"[^x]*.png")].each do |fname|
        yield fname
      end
    end
  end
end
