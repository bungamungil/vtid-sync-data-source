import ConsoleKit
import Foundation


@main
struct VTIDSyncDataSource {
    
    static func main() async throws {
        let console = Terminal()
        let input = CommandInput(arguments: CommandLine.arguments)
        
        var commands = Commands(enableAutocomplete: true)
        commands.use(SyncDataSourceCommand(), as: "sync", isDefault: true)
        
        do {
            let group = commands.group(help: "Sync data source")
            try console.run(group, input: input)
        } catch {
            console.error("\(error)")
            exit(1)
        }
    }
    
}
