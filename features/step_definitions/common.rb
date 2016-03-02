if OSX
  EXTRA_OBJC_FLAGS = ''
else
  EXTRA_OBJC_FLAGS = '-I/usr/include/GNUstep'
end

Given /^a test file named "([^"]*)"$/ do |file|
  step %{a file named "test_files/#{file}.h" should exist}
end

Given /^a test file named "([^"]*)" in "([^"]*)"$/ do |file, path|
  step %{a file named "test_files/#{path}/#{file}.h" should exist}
end

Given /^an expected file named "([^"]*)"$/ do |file|
  step %{a file named "test_files/#{file}.d" should exist}
end

Given /^an expected file named "([^"]*)" in "([^"]*)"$/ do |file, path|
  step %{a file named "test_files/#{path}/#{file}.d" should exist}
end

Then /^the files "([^"]*)" and "([^"]*)" should be equal$/ do |file1, file2|
  check_file_content(file1, IO.read(file2), true)
end

When /^I successfully convert the test file "([^"]*)"$/ do |file|
  step %{I successfully run `dstep test_files/#{file}.h -o #{file}.d`}
end

When /^I successfully convert the test file "([^"]*)" in "([^"]*)" with the flags "([^"]*)"$/ do |file, path, flags|
  step %{I successfully run `dstep test_files/#{path}/#{file}.h #{flags} -o #{file}.d`}
end

When /^I successfully convert the test file "([^"]*)" in "([^"]*)"$/ do |file, path|
  step %{I successfully run convert the test file "#{file}" in "#{path}" with the flags ""}
end

Then /^I test the file "([^"]*)"$/ do |file|
  step %{a test file named "#{file}"}
  step %{an expected file named "#{file}"}
  step %{I successfully convert the test file "#{file}"}
  step %{the files "#{file}.d" and "test_files/#{file}.d" should be equal}
end

Then /^I test the file "([^"]*)" in "([^"]*)"$/ do |file, path|
  step %{a test file named "#{file}" in "#{path}"}
  step %{an expected file named "#{file}" in "#{path}"}
  step %{I successfully convert the test file "#{file}" in "#{path}"}
  step %{the files "#{file}.d" and "test_files/#{path}/#{file}.d" should be equal}
end

Then /^I test the file "([^"]*)" with filter "([^"]*)" and prefix "([^"]*)"$/ do |file, filter, prefix|
    step %{a test file named "#{file}"}
    step %{an expected file named "#{file}"}
    step %{I successfully convert the test file "#{file}" in "" with the flags "--import-filter #{filter} --import-prefix #{prefix}"}
    step %{the files "#{file}.d" and "test_files/#{file}.d" should be equal}
end

if OSX
  Then /^I test the Objective\-C file "([^"]*)" in "([^"]*)"$/ do |file, path|
    step %{a test file named "#{file}" in "#{path}"}
    step %{an expected file named "#{file}" in "#{path}"}
    step %{I successfully convert the test file "#{file}" in "#{path}" with the flags "-ObjC #{EXTRA_OBJC_FLAGS}"}
    step %{the files "#{file}.d" and "test_files/#{path}/#{file}.d" should be equal}
  end
end
