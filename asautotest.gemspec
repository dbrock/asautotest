Gem::Specification.new do |gem|
  gem.name = "asautotest"
  gem.version = "0.0.3"

  gem.summary = "Detects source changes and compiles ActionScript."
  gem.homepage = "http://github.com/dbrock/asautotest"

  gem.executables = ["asautotest", "flash-policy-server"]
  gem.files = Dir["lib/**/*", "bin/*", "README.rdoc", "LICENSE"]

  gem.author = "Daniel Brockman"
  gem.email = "daniel@gointeractive.se"
end
