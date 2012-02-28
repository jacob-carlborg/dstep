Given /^a test file named "([^"]*)"$/ do |file|
  Given %{a file named "test_files/#{file}.h" should exist}
end

Given /^a test file named "([^"]*)" in "([^"]*)"$/ do |file, path|
  Given %{a file named "test_files/#{path}/#{file}.h" should exist}
end

Given /^a expected file named "([^"]*)"$/ do |file|
  Given %{a file named "test_files/#{file}.d" should exist}
end

Given /^a expected file named "([^"]*)" in "([^"]*)"$/ do |file, path|
  Given %{a file named "test_files/#{path}/#{file}.d" should exist}
end

Then /^the files "([^"]*)" and "([^"]*)" should be equal$/ do |file1, file2|
  file2_content = IO.read(file2)
  Then %{the file "#{file1}" should contain "#{file2_content}"}
end

Then /^I test the file "([^"]*)"$/ do |file|
  Given %{a test file named "#{file}"}
  And %{a expected file named "#{file}"}
  When %{I successfully run `dstep #{file}.c -o #{file}.d`}
  Then %{the files "#{file}.d" and "test_files/#{file}.d" should be equal}
end

Then /^I test the file "([^"]*)" in "([^"]*)"$/ do |file, path|
  Given %{a test file named "#{file}" in "#{path}"}
  And %{a expected file named "#{file}" in "#{path}"}
  When %{I successfully run `dstep #{file}.c -o #{file}.d`}
  Then %{the files "#{file}.d" and "test_files/#{path}/#{file}.d" should be equal}
end