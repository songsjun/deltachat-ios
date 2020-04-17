import Foundation
import UIKit
import AVFoundation
import DcCore

struct Utils {

    static func isValid(email: String) -> Bool {
        let emailRegEx = "(?:[a-z0-9!#$%\\&'*+/=?\\^_`{|}~-]+(?:\\.[a-z0-9!#$%\\&'*+/=?\\^_`{|}"
            + "~-]+)*|\"(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21\\x23-\\x5b\\x5d-\\"
            + "x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])*\")@(?:(?:[a-z0-9](?:[a-"
            + "z0-9-]*[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\\[(?:(?:25[0-5"
            + "]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-"
            + "9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21"
            + "-\\x5a\\x53-\\x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])+)\\])"

        let emailTest = NSPredicate(format: "SELF MATCHES[c] %@", emailRegEx)
        return emailTest.evaluate(with: email)
    }


    static func isEmail(url: URL) -> Bool {
        let mailScheme = "mailto"
        if let scheme = url.scheme {
            return mailScheme == scheme && isValid(email: url.absoluteString.substring(mailScheme.count + 1, url.absoluteString.count))
        }
        return false
    }

    static func getEmailFrom(_ url: URL) -> String {
        let mailScheme = "mailto"
        return url.absoluteString.substring(mailScheme.count + 1, url.absoluteString.count)
    }

    static func formatAddressForQuery(address: [String: String]) -> String {
        // Open address in Apple Maps app.
        var addressParts = [String]()
        let addAddressPart: ((String?) -> Void) = { part in
            guard let part = part else {
                return
            }
            guard !part.isEmpty else {
                return
            }
            addressParts.append(part)
        }
        addAddressPart(address["Street"])
        addAddressPart(address["Neighborhood"])
        addAddressPart(address["City"])
        addAddressPart(address["Region"])
        addAddressPart(address["Postcode"])
        addAddressPart(address["Country"])
        return addressParts.joined(separator: ", ")
    }

    // compression needs to be done before in UIImage.dcCompress()
    static func saveImage(image: UIImage) -> String? {
        guard let directory = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask,
            appropriateFor: nil, create: false) as NSURL else {
            return nil
        }

        guard let data = image.isTransparent() ? image.pngData() : image.jpegData(compressionQuality: 1.0) else {
            return nil
        }

        do {
            let timestamp = Double(Date().timeIntervalSince1970)
            let path = directory.appendingPathComponent("\(timestamp).jpg")
            try data.write(to: path!)
            return path?.relativePath
        } catch {
            logger.info(error.localizedDescription)
            return nil
        }
    }

    static func hasAudioSuffix(url: URL) -> Bool {
        ///TODO: add more file suffixes
        return url.absoluteString.hasSuffix("wav")
    }

    static func generateThumbnailFromVideo(url: URL?) -> UIImage? {
        guard let url = url else {
            return nil
        }
        do {
            let asset = AVURLAsset(url: url)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }

    static func getDeviceLanguage() -> String? {
        // some device languages have suffixes (like en-aus etc.) so we want to cut suffixes off
        guard let lang = Locale.preferredLanguages.first?.split(separator: "-").first else {
            return nil
        }
        return String(lang)
    }
}
