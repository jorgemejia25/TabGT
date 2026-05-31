import Foundation

enum ThemeImporter {
    static func decode(
        data: Data,
        reservedBuiltInIDs: Set<String>,
        existingCustomSlugs: Set<String>
    ) throws -> TabGTThemeDTO {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys

        let dto: TabGTThemeDTO
        do {
            dto = try decoder.decode(TabGTThemeDTO.self, from: data)
        } catch {
            throw ThemeImportError.decodeFailed(error.localizedDescription)
        }

        return try dto.validated(
            reservedBuiltInIDs: reservedBuiltInIDs,
            existingCustomSlugs: existingCustomSlugs
        )
    }

    static func importTheme(
        from url: URL,
        reservedBuiltInIDs: Set<String>,
        existingCustomSlugs: Set<String>
    ) throws -> TabGTThemeDTO {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ThemeImportError.fileReadFailed
        }

        return try decode(
            data: data,
            reservedBuiltInIDs: reservedBuiltInIDs,
            existingCustomSlugs: existingCustomSlugs
        )
    }
}
