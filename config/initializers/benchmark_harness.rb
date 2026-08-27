# Loads Llm::Harness classes from lib/benchmark/harness, which is ignored by
# autoload_lib because its path (lib/benchmark/harness/*) does not map to
# Llm::Harness under Zeitwerk (it would map to Benchmark::Harness).
Dir[Rails.root.join("lib/benchmark/harness/*.rb")].each { |path| require path }
