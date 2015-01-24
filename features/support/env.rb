require "aruba/cucumber"
require "fileutils"

WORKING_DIRECTORY = File.join "tmp", "aruba"

OSX = RUBY_PLATFORM =~ /darwin/ ? true : false
WINDOWS = RUBY_PLATFORM =~ /windows/ || RUBY_PLATFORM =~ /mingw/ ? true : false

DYLIB = if OSX
  "dylib"
elsif WINDOWS
  "dll"
else
  "so"
end

LIB = if WINDOWS
  ""
else
  "lib"
end

def lib_name (name)
  "#{LIB}#{name}.#{DYLIB}"
end

Before do
  FileUtils.mkdir_p WORKING_DIRECTORY
  FileUtils.cp_r "test_files", WORKING_DIRECTORY

  name = lib_name("clang")

  if WINDOWS
    FileUtils.cp name, File.join(WORKING_DIRECTORY, name)
  else
    File.symlink "../../#{name}", File.join(WORKING_DIRECTORY, name)
  end
end