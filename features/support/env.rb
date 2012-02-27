require "aruba/cucumber"
require "fileutils"

Before do
  p 1
  FileUtils.mkdir_p "tmp/aruba"
  p 2
  FileUtils.cp_r "test_files", "tmp/aruba"
end