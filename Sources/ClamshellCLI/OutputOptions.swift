import ArgumentParser

struct OutputOptions: ParsableArguments {
  @Flag(name: .long, help: "Suppress successful output.")
  var quiet = false
}
