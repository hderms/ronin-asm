require 'ronin/yard/handlers'

YARD::Rake::YardocTask.new do |t|
  t.files   = ['lib/**/*.rb']
  t.options = [
    '--protected',
    '--files', 'History.rdoc',
    '--title', 'Ronin ASM'
  ]
end

task :docs => :yard
