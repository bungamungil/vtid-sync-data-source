//
//  SyncDataSourceCommand.swift
//  
//
//  Created by Bunga Mungil on 05/07/23.
//

import ConsoleKit
import FluentKit
import Foundation
import VTIDCommandUtils
import VTIDCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif


final class SyncDataSourceCommand: Command {
    
    struct Signature: CommandSignature {
        
        @Option(name: "bearer-token")
        var bearerToken: String?
        
    }
    
    var help: String = "Sync data source"
    
    func run(using context: CommandContext, signature: Signature) throws {
        let accessToken = signature.bearerToken ?? context.console.ask("Bearer Token : ")
        let sem = DispatchSemaphore(value: 0)
        let URLString = "https://sheets.googleapis.com/v4/spreadsheets/\(Environment.get("SPREADSHEET_ID") ?? "")/values/\(Environment.get("SPREADSHEET_RANGE") ?? "")"
        let request = createRequest(for: URL(string: URLString)!, with: accessToken)
        let task = URLSession.shared.dataTask(with: request) { data, urlResponse, error in
            defer {
                sem.signal()
            }
            if let unwrappedData = data {
                self.handle(data: unwrappedData, using: context)
            }
            if let unwrappedError = error {
                self.handle(error: unwrappedError, using: context)
            }
        }
        task.resume()
        sem.wait()
    }
    
    private func createRequest(for url: URL, with bearerToken: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        return request
    }
    
    private func handle(data: Data, using context: CommandContext) {
        do {
            self.handle(
                response: try JSONDecoder().decode(SpreadsheetValuesResponse.self, from: data),
                using: context
            )
        } catch {
            self.handle(error: error, using: context)
        }
    }
    
    private func handle(response: SpreadsheetValuesResponse, using context: CommandContext) {
        let values = response.values
        for row in 2 ..< values.count {
            let value = values[row]
            if value.count > 13 && value[12] == "GRADUATED" {
                continue
            }
            if value.count > 1 && !value[0].isEmpty { // Row A
                let channelID = value[0]
                let row = SourceTableRowModel(channelID: channelID)
                context.console.output("Found channel ID : ", style: .init(color: .brightMagenta), newLine: false)
                context.console.output("\(channelID)", style: .init(color: .brightMagenta, isBold: true), newLine: false)
                if value.count > 2 && !value[1].isEmpty { // Row B
                    context.console.output(" named : ", style: .init(color: .brightMagenta), newLine: false)
                    context.console.output("\(value[1])", style: .init(color: .brightMagenta, isBold: true), newLine: false)
                    row.vtuberName = value[1]
                }
                if value.count > 8 && !value[7].isEmpty { // Row H
                    row.vtuberPersona = value[7]
                }
                if value.count > 13 && !value[12].isEmpty { // Row M
                    row.vtuberAffiliation = value[12]
                }
                if value.count > 14 && !value[13].isEmpty { // Row N
                    row.vtuberAffiliation = value[13]
                }
                do {
                    try row.save(on: context.db).wait()
                } catch {
                    self.handle(error: error, using: context)
                    continue
                }
            }
        }
    }
    
    private func handle(error: Error, using context: CommandContext) {
        context.console.error(error.localizedDescription)
    }

}
