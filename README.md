# DocScanner — แอปสแกนเอกสารสำหรับ iOS

แอป SwiftUI สำหรับสแกนเอกสารด้วยกล้อง iPhone แล้วเก็บไว้ในเครื่อง ส่งออกเป็น PDF ได้ และอ่านข้อความไทย/อังกฤษในเอกสารให้ด้วย (OCR)

> ✅ build ผ่านบน GitHub Actions แล้ว (Xcode 16.4, ไม่มี error และไม่มี warning ของ Swift)
> ⚠️ แต่ยังไม่ได้ทดสอบการใช้งานจริงบน iPhone

## ฟีเจอร์

- **สแกนด้วยกล้อง** ใช้ `VNDocumentCameraViewController` ของ VisionKit ที่หาขอบกระดาษ ปรับมุมมองให้ตรง และสแกนต่อกันได้หลายหน้า
- **นำเข้าจากรูปภาพ** เลือกรูปจากอัลบั้ม (ใช้ทดสอบบน Simulator ได้ เพราะ Simulator ไม่มีกล้อง)
- **รายการเอกสาร** มีภาพตัวอย่างหน้าแรก วันที่ จำนวนหน้า และช่องค้นหาที่ค้นได้ทั้งชื่อเอกสารและข้อความที่อ่านได้
- **ดูเอกสาร** แสดงหน้าเป็นตาราง แตะเพื่อเปิดเต็มจอ ปัดซ้ายขวาเพื่อเปลี่ยนหน้า บีบหรือแตะสองครั้งเพื่อซูม
- **จัดการเอกสาร** เปลี่ยนชื่อ สแกนเพิ่มหน้า ลบหน้า ลบเอกสาร
- **ส่งออก PDF** หลายหน้า (PDFKit/UIKit) แล้วแชร์ผ่านเมนูแชร์ของระบบ (AirDrop, Mail, LINE, บันทึกลง Files ฯลฯ)
  PDF ที่ได้จะมีข้อความ OCR ซ่อนอยู่ใต้ภาพ จึงค้นหาและคลุมข้อความใน PDF ได้
- **อ่านข้อความ (OCR)** ใช้ `VNRecognizeTextRequest` ของ Vision รองรับภาษาไทยและอังกฤษ ทำงานในเครื่องทั้งหมด ไม่ส่งข้อมูลออกไปไหน
  ดู คัดลอก หรือแชร์ข้อความทั้งเอกสาร หรือคัดลอกทีละหน้าได้

## ข้อกำหนด

| สิ่งที่ต้องมี | หมายเหตุ |
| --- | --- |
| iPhone/iPad ที่ใช้ **iOS 17 ขึ้นไป** | OCR ภาษาไทยมีตั้งแต่ iOS 17 |
| **Mac + Xcode 16 ขึ้นไป** หรือ GitHub Actions (macOS runner) | Windows build แอป iOS ไม่ได้ |
| **Apple ID** | ใช้เซ็นแอปก่อนติดตั้งลง iPhone (Apple ID ฟรีก็ได้) |
| [XcodeGen](https://github.com/yonaskolb/XcodeGen) | ใช้สร้างไฟล์ `DocScanner.xcodeproj` จาก `project.yml` |

> กล้องสแกนเอกสารใช้บน Simulator ไม่ได้ ต้องลองบน iPhone จริง (บน Simulator ใช้ "นำเข้าจากรูปภาพ" แทนได้)

## วิธีที่ 1: Build บน Mac ด้วย Xcode (แนะนำ)

1. คัดลอกโฟลเดอร์ `DocScanner` นี้ไปไว้บน Mac (หรือ `git clone` ถ้าอัปขึ้น GitHub แล้ว)
2. ติดตั้ง XcodeGen แล้วสร้างโปรเจกต์ Xcode

   ```bash
   brew install xcodegen
   ```

   ```bash
   cd DocScanner && xcodegen generate
   ```

3. เปิด `DocScanner.xcodeproj` ด้วย Xcode
4. ตั้งค่าการเซ็นแอป: เลือก target **DocScanner** → แท็บ **Signing & Capabilities**
   - ติ๊ก **Automatically manage signing**
   - ที่ **Team** เลือก Apple ID ของคุณ (ถ้ายังไม่มี ให้กด Add Account… แล้วล็อกอิน)
   - ถ้า Xcode แจ้งว่า Bundle Identifier ถูกใช้ไปแล้ว ให้เปลี่ยน `com.rroimakkub.docscanner` เป็นชื่ออื่นที่ไม่ซ้ำ
     (แก้ใน `project.yml` ด้วย เพื่อไม่ให้ค่าหายตอนรัน `xcodegen generate` ครั้งต่อไป)
5. เสียบ iPhone เข้ากับ Mac แล้วกด **Trust** บน iPhone
6. เปิด **Developer Mode** บน iPhone: การตั้งค่า → ความเป็นส่วนตัวและความปลอดภัย → โหมดนักพัฒนา → เปิด แล้วรีสตาร์ต
7. ใน Xcode เลือก iPhone ของคุณที่แถบด้านบน แล้วกด **Run** (⌘R)
8. ครั้งแรกที่เปิดแอป iPhone อาจไม่ยอมให้เปิด ให้ไปที่ การตั้งค่า → ทั่วไป → การจัดการ VPN และอุปกรณ์ → เลือก Apple ID ของคุณ → **เชื่อถือ**

> ถ้าใช้ Apple ID ฟรี (ไม่ได้สมัคร Apple Developer Program ปีละ 99 USD) แอปจะใช้ได้ **7 วัน** แล้วต้องกด Run จาก Xcode ใหม่
> และติดตั้งแอปแบบนี้ได้พร้อมกันไม่เกิน 3 แอป

## วิธีที่ 2: ไม่มี Mac — ให้ GitHub Actions build ให้

โปรเจกต์นี้มี workflow ที่ `.github/workflows/build.yml` ซึ่งจะ build แอปบนเครื่อง macOS ของ GitHub แล้วได้ไฟล์ `.ipa` ที่ **ยังไม่ได้เซ็น** ออกมา
วิธีนี้ยังเป็นการเช็กด้วยว่าโค้ด compile ผ่านหรือไม่

1. สร้าง repository ใหม่บน GitHub แล้วอัปโฟลเดอร์นี้ขึ้นไป

   ```bash
   git init && git add . && git commit -m "Initial DocScanner app" && git branch -M main
   ```

   ```bash
   git remote add origin https://github.com/<ชื่อผู้ใช้>/DocScanner.git && git push -u origin main
   ```

   (repo นี้สร้างไว้แล้วที่ https://github.com/Rroimakkub/DocScanner แบบ private)

2. เปิดแท็บ **Actions** ใน repo แล้วรอ workflow **Build iOS app** ทำงานเสร็จ (สั่งรันเองได้ด้วยปุ่ม Run workflow)
   - push ที่แก้แค่ไฟล์ `.md` จะไม่สั่ง build เพื่อประหยัดโควตา
   - ถ้าขึ้นสีแดง ให้เปิด log ของขั้นตอน "Build" ดู error ของ Swift แล้วนำมาแก้
3. เมื่อสำเร็จ ดาวน์โหลด artifact **DocScanner-unsigned-ipa** (ได้ไฟล์ zip ข้างในเป็น `DocScanner-unsigned.ipa`)
4. เซ็นและติดตั้งลง iPhone จาก Windows ด้วยเครื่องมือ sideload เช่น [Sideloadly](https://sideloadly.io) หรือ [AltStore](https://altstore.io)
   - ต้องติดตั้ง iTunes เวอร์ชันจากเว็บ Apple (ไม่ใช่จาก Microsoft Store) เพื่อให้ Windows คุยกับ iPhone ได้
   - เครื่องมือเหล่านี้จะขอ Apple ID มาเซ็นแอป แนะนำให้ใช้ Apple ID สำรอง ไม่ใช่บัญชีหลัก
   - เปิด Developer Mode และกด "เชื่อถือ" บน iPhone เหมือนขั้นตอนที่ 6 และ 8 ของวิธีที่ 1
   - Apple ID ฟรีมีอายุ 7 วันเช่นกัน ต้องเซ็นซ้ำเมื่อครบกำหนด

> เวลา build บน macOS ของ GitHub Actions ฟรีสำหรับ repo สาธารณะ
> ถ้าเป็น repo ส่วนตัว จะถูกนับโควตาแบบ macOS (ใช้โควตาเร็วกว่า Linux ราว 10 เท่า)

ถ้าสมัคร Apple Developer Program แล้ว จะใช้ **Xcode Cloud** หรือ TestFlight ส่งแอปเข้าเครื่องได้สะดวกกว่า และแอปไม่หมดอายุทุก 7 วัน

## โครงสร้างโปรเจกต์

```
DocScanner/
├── project.yml                  # สเปก XcodeGen (target, iOS 17, bundle id, การตั้งค่า build)
├── .github/workflows/build.yml  # build บน GitHub Actions แล้วได้ .ipa ที่ยังไม่เซ็น
└── DocScanner/
    ├── Info.plist               # มี NSCameraUsageDescription (ข้อความขอใช้กล้อง)
    ├── Assets.xcassets          # ไอคอนแอปและสีหลัก
    ├── App/DocScannerApp.swift  # จุดเริ่มแอป
    ├── Models/ScanDocument.swift        # ข้อมูลเอกสาร หน้า และข้อความ OCR
    ├── Services/
    │   ├── ScanStore.swift      # สถานะของแอป: สร้าง/เปลี่ยนชื่อ/ลบ, คิว OCR, ส่งออก PDF
    │   ├── ScanFiles.swift      # อ่าน/เขียนไฟล์ใน Documents/Scans
    │   ├── ImageProcessing.swift# หมุนภาพให้ตั้งตรง ย่อขนาด ทำภาพตัวอย่าง
    │   ├── TextRecognizer.swift # OCR ด้วย Vision (ไทย + อังกฤษ)
    │   └── PDFExporter.swift    # สร้าง PDF หลายหน้าพร้อมชั้นข้อความที่ค้นหาได้
    └── Views/
        ├── List/                # หน้ารายการเอกสาร
        ├── Detail/              # หน้าเอกสาร ดูภาพเต็มจอ ซูม และดูข้อความ
        ├── Capture/             # กล้องสแกนเอกสาร และนำเข้าจากรูปภาพ
        └── Shared/              # ส่วนที่ใช้ร่วมกัน (ภาพตัวอย่าง, เมนูแชร์ ฯลฯ)
```

## การเก็บข้อมูล

ทุกอย่างเก็บไว้ในเครื่องเท่านั้น ที่โฟลเดอร์ Documents ของแอป:

```
Documents/Scans/<รหัสเอกสาร>/document.json   # ชื่อ วันที่ ลำดับหน้า และข้อความ OCR
Documents/Scans/<รหัสเอกสาร>/<รหัสหน้า>.jpg   # ภาพแต่ละหน้า (JPEG)
```

- OCR ทำงานเบื้องหลังทีละหน้าหลังบันทึกเสร็จ ถ้าปิดแอปไปก่อน จะอ่านต่อให้เองเมื่อเปิดแอปครั้งถัดไป
- ไฟล์ PDF ที่ส่งออกจะสร้างไว้ในโฟลเดอร์ชั่วคราว ระบบลบให้เองภายหลัง
- ข้อมูลจะถูกสำรองไปกับ iCloud Backup / การสำรองข้อมูลของ iPhone ตามปกติ

## ปรับแต่ง

- **ชื่อแอปบนหน้าจอโฮม**: `CFBundleDisplayName` ใน `DocScanner/Info.plist`
- **Bundle ID / เวอร์ชัน**: `project.yml` (`PRODUCT_BUNDLE_IDENTIFIER`, `MARKETING_VERSION`)
- **ภาษาที่ใช้ OCR**: `TextRecognizer.preferredLanguages` ใน `Services/TextRecognizer.swift`
- **ความละเอียดภาพที่เก็บ / คุณภาพ JPEG**: `ImageProcessing.maxStoredDimension` และ `ScanFiles.jpegQuality`
- **ขนาดหน้า PDF**: `PDFExporter.pageWidth` (595 pt = ความกว้าง A4)

## ข้อจำกัดที่รู้อยู่

- build ผ่านแล้ว แต่ยังไม่ได้ทดสอบบนเครื่องจริง (ดูหมายเหตุด้านบน)
- ยังจัดลำดับหน้าใหม่ไม่ได้ ทำได้แค่เพิ่มต่อท้ายและลบ
- ชั้นข้อความใน PDF วางตามตำแหน่งที่ OCR ตรวจพบ การคลุมข้อความใน PDF อาจไม่ตรงเป๊ะกับภาพ
- ข้อความ UI เป็นภาษาไทยในโค้ดโดยตรง ยังไม่ได้แยกเป็นไฟล์แปลภาษา
