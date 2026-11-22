# Temporarily sets environment variables (nil unsets one) for the duration of a block.
# Tests run in parallel processes, not threads, so this does not leak into other tests.
module EnvTestHelper
  def with_env(variables)
    previous = variables.keys.to_h { |name| [ name, ENV[name] ] }
    variables.each { |name, value| ENV[name] = value }
    yield
  ensure
    previous&.each { |name, value| ENV[name] = value }
  end
end
