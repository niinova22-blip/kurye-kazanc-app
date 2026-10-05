// swift-tools-version:5.9
//
// KuryeCore: uygulamanin saf is mantigi (hesaplama, Turkce sayi ayristirma, OCR regex sablonlari, donemler).
// Kaynaklar uygulamayla AYNI dosyalardir (KuryeKazanc/Core) — kopya yok.
//
// Amac: Mac/CI beklemeden Windows (veya Linux) uzerinde saniyeler icinde test:
//     swift test
// iOS uygulamasi bu paketi kullanmaz; Xcode projesi (project.yml) Core dosyalarini dogrudan derler.
import PackageDescription

let package = Package(
    name: "KuryeCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "KuryeCore", targets: ["KuryeCore"]),
    ],
    targets: [
        .target(
            name: "KuryeCore",
            path: "KuryeKazanc/Core"
        ),
        .testTarget(
            name: "KuryeCoreTests",
            dependencies: ["KuryeCore"],
            path: "KuryeKazancTests/Core"
        ),
    ]
)
