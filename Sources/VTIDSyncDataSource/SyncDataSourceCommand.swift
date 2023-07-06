//
//  SyncDataSourceCommand.swift
//  
//
//  Created by Bunga Mungil on 05/07/23.
//

import ConsoleKit
import FluentKit
import FluentSQL
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
        let URL = createURL(
            string: URLString,
            queryParameters: [
                "dateTimeRenderOption": "FORMATTED_STRING",
                "valueRenderOption": "FORMULA",
            ]
        )
        let request = createRequest(for: URL, with: accessToken)
        let task = URLSession.shared.dataTask(with: request) { data, urlResponse, error in
            defer {
                sem.signal()
            }
            if let unwrappedError = error {
                return self.handle(error: unwrappedError, using: context)
            }
            if let unwrappedData = data {
                return self.handle(data: unwrappedData, using: context)
            }
        }
        task.resume()
        sem.wait()
    }
    
    private func createURL(string: String, queryParameters: [String: String]) -> URL {
        var URLComponents = URLComponents(string: string)!
        URLComponents.queryItems = queryParameters.map { key, value in
            URLQueryItem(name: key, value: value)
        }
        URLComponents.percentEncodedQuery = URLComponents.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")
        return URLComponents.url!
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
        var channelIDs: [String] = []
        for row in 2 ..< values.count {
            let vtuber = values[row]
            if !vtuber.isGraduated, let ch = vtuber.asSourceTableRow {
                channelIDs.append(ch.channelID)
                let row = self.findOrCreateRow(for: ch.channelID, from: ch, using: context)
                do {
                    try row.save(on: context.db).wait()
                } catch {
                    self.handle(error: error, using: context)
                    continue
                }
            }
        }
        self.removeRowsNotIncluded(in: channelIDs, using: context)
    }
    
    private func findOrCreateRow(for channelID: String, from ch: SourceTableRow, using context: CommandContext) -> SourceTableRowModel {
        let row = (
            try? SourceTableRowModel.query(on: context.db)
                .filter(\.$channelID, .equal, channelID)
                .first()
                .wait()
            ) ?? SourceTableRowModel(channelID: channelID)
        context.console.output("Found channel ID : ", style: .init(color: .brightMagenta), newLine: false)
        context.console.output("\(channelID)", style: .init(color: .brightMagenta, isBold: true), newLine: false)
        context.console.output(" named : ", style: .init(color: .brightMagenta), newLine: false)
        context.console.output("\(ch.vtuberName ?? "")", style: .init(color: .brightMagenta, isBold: true), newLine: false)
        row.vtuberName = ch.vtuberName
        row.vtuberPersona = ch.vtuberPersona
        row.vtuberBirthday = ch.vtuberBirthday
        row.vtuberAffiliation = ch.vtuberAffiliation
        row.vtuberAffiliationLogo = ch.vtuberAffiliationLogo
        context.console.output("", newLine: true)
        return row
    }
    
    private func removeRowsNotIncluded(in channelIDs: [String], using context: CommandContext) {
        if let db = context.db as? SQLDatabase {
            do {
                try db.delete(from: SourceTableRowModel.schema)
                    .where("channel_id", .notIn, channelIDs)
                    .run()
                    .wait()
            } catch {
                self.handle(error: error, using: context)
            }
        }
    }
    
    private func handle(error: Error, using context: CommandContext) {
        context.console.error(String(describing: error))
    }

}


extension Array where Element == Value {
    
    fileprivate var asSourceTableRow: SourceTableRow? {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMMM"
        if self.count > 1 && !self[0].isEmpty, let channelID = self[0].string?.components(separatedBy: "\"").dropLast().last {
            var row = _SourceTableRow(channelID: channelID)
            if self.count > 2 && !self[1].isEmpty { // Row B
                row.vtuberName = self[1].string
            }
            if self.count > 8 && !self[7].isEmpty { // Row H
                row.vtuberPersona = self[7].string
            }
            if self.count > 12 && !self[11].isEmpty, let dateStr = self[11].string { // Row L
                row.vtuberBirthday = formatter.date(from: dateStr)
            }
            if self.count > 13 && !self[12].isEmpty { // Row M
                row.vtuberAffiliation = self[12].string
            }
            if self.count > 14 && !self[13].isEmpty { // Row N
                row.vtuberAffiliationLogo = self[13].string?.components(separatedBy: "\"").dropLast().last
            }
            return row
        }
        return nil
    }
    
    fileprivate var isGraduated: Bool {
        return self.count > 13 && self[12].string == "GRADUATED"
    }
    
}


fileprivate struct _SourceTableRow: SourceTableRow {
    var channelID: String
    var vtuberName: String?
    var vtuberPersona: String?
    var vtuberBirthday: Date?
    var vtuberAffiliation: String?
    var vtuberAffiliationLogo: String?
    var createdAt: Date?
    var updatedAt: Date?
}
