import Darwin
import Foundation

@main
enum ClamshellHelper {
    static func main() {
        FileHandle.standardError.write(Data("Invalid helper invocation.\n".utf8))
        exit(EX_USAGE)
    }
}
