guard :rake, task: 'compile' do
  watch(%r{^ext/(.+)\.[ch]$})
end

guard :rspec, cmd: 'bundle exec rspec --color --fail-fast' do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/(.+)\.rb$})     { |m| "spec/lib/#{m[1]}_spec.rb" }
  watch('spec/spec_helper.rb')  { 'spec' }
  watch(%r{^ext/(.+)\.[ch]$})   { 'spec' }
end

guard :rubocop, cli: '-D -a' do
  watch(/.+\.rb$/)
  watch(%r{(?:.+/)?\.rubocop\.yml$}) { |m| File.dirname(m[0]) }
end
