# I05 · Sơ đồ hệ thống (System Diagram)

---

## 1. Bối cảnh ứng dụng theo Charter mục 1

> *“Khối tính sin/cos để tạo dạng sóng trong bộ phát tín hiệu thử, không dùng bảng tra lớn.”*

Mệnh đề *“không dùng bảng tra lớn”* là ràng buộc thật sự của đề. Một bảng tra 256 mục × 8
bit cho `sin` cộng 256 mục cho `cos` là **4096 bit** ROM — trên một ô Tiny Tapeout không
có macro ROM, nó phải trở thành logic tổ hợp và sẽ rất đắt. CORDIC đổi bộ nhớ đó lấy
**8 hằng số arctan** cộng một vòng lặp cộng/dịch.

```
 ┌─────────────────────── BỘ PHÁT TÍN HIỆU THỬ (DDS) ───────────────────────────────┐
 │                                                                                   │
 │  ┌─────────────────────┐    Điều chỉnh tần số                                     │
 │  │ Thanh ghi bước pha  │◀────────────────────────── từ giao diện cấu hình         │
 │  │      Δφ (8 bit)     │                                                          │
 │  └──────────┬──────────┘                                                          │
 │             │                                                                     │
 │             ▼                                                                     │
 │  ┌─────────────────────┐   phase[7:0]                                             │
 │  │ BỘ TÍCH LUỸ PHA     │───────────────┐   ← bộ đếm 8 bit tự quay vòng            │
 │  │  φ ← φ + Δφ  (mod 256)│              │      (đề D01), 256 mã = 1 vòng tròn      │
 │  └─────────────────────┘               │                                          │
 │                                        ▼ angle[7:0]                               │
 │   ┌──────────────┐  start       ╔══════════════════════════════════╗              │
 │   │ FSM phát mẫu │─────────────▶║         ▛▀▀▀▀▀ I05 ▀▀▀▀▀▜         ║              │
 │   │              │◀── done ─────║        i05_cordic_core           ║              │
 │   └──────────────┘              ║                                  ║              │
 │                                 ║   8 vòng lặp CỘNG + DỊCH         ║              │
 │                                 ║   (KHÔNG có phép nhân)           ║              │
 │                                 ║                                  ║              │
 │                                 ╚═══════╤═══════════════╤══════════╝              │
 │                                sin_out[7:0]        cos_out[7:0]                   │
 │                                         ▼               ▼                         │
 │                          ┌──────────────────┐  ┌──────────────────┐               │
 │                          │  PWM 8 bit (D06) │  │  PWM 8 bit (D06) │               │
 │                          │  hoặc R-2R ngoài │  │                  │               │
 │                          └────────┬─────────┘  └────────┬─────────┘               │
 │                                   ▼                     ▼                         │
 │                             kênh I (sin)          kênh Q (cos)                    │
 └───────────────────────────────────────────────────────────────────────────────────┘
          ╔════╗ = ranh giới của I05 trong hồ sơ này
```

**Con số hệ thống phải nói ra:** I05 tốn **10 chu kỳ / mẫu**. Với clock 10 MHz thì tần số
lấy mẫu tối đa là 1 MHz, và theo Nyquist thì dạng sóng ra tối đa ≈ **500 kHz** — nhưng
thực tế cần ≥ 16 mẫu/chu kỳ để dạng sóng dùng được, nên giới hạn thực dụng là ≈ **60 kHz**.
Đủ cho tín hiệu thử âm tần, **không** đủ cho RF.

## 2. Ranh giới khối

| Chức năng | Thuộc I05? | Ghi chú |
|---|:-:|---|
| 8 vòng lặp CORDIC chế độ quay | ✅ | `always_comb` dòng 92–100 + `always_ff` dòng 130–150 |
| Bảng hằng số arctan (8 mục) | ✅ | `function atan_const`, dòng 34–45 |
| Bù hệ số `1/K₈` = `X_INIT` | ✅ | dòng 16 |
| Gập góc về một phần tư + khôi phục dấu | ✅ | dòng 74–90, 139–144 |
| Lượng tử hoá Q1.14 → Q0.7 + kẹp bão hoà | ✅ | `function quantize_q14`, dòng 47–67 |
| Bắt tay `start`/`busy`/`done` | ✅ | |
| Bộ tích luỹ pha (sinh `angle`) | ❌ | Tầng ngoài (đề D01/D05) |
| PWM / DAC | ❌ | Tầng ngoài (đề D06) |
| Điều chỉnh biên độ, offset | ❌ | Tầng ngoài |
| CORDIC chế độ **vector** (`atan2`, độ lớn) | ❌ | Charter mục 3 — ngoài phạm vi |
| Độ chính xác cao hơn, dấu phẩy động | ❌ | Charter mục 3 — ngoài phạm vi |
| Ánh xạ chân Tiny Tapeout | ❌ | **Charter mục 4 đòi nhưng RTL chưa có** |

## 3. Hợp đồng với tầng ngoài

| Bên | Nghĩa vụ |
|---|---|
| Tầng ngoài → I05 | `angle` ổn định tại cạnh có `start = 1`; không `X`/`Z`; giữ `rst_n = 0` qua ≥ 1 cạnh clock (reset **đồng bộ**) |
| Tầng ngoài → I05 | **Không** dùng riêng `busy` để phát `start` (xem `control.md` §4) |
| Tầng ngoài → I05 | **Chấp nhận sai số**: đầu ra là xấp xỉ, sai tới ≈ 5 mã trên 128. Nếu ứng dụng cần chính xác hơn, I05 **không** phải khối phù hợp |
| I05 → tầng ngoài | `done` là xung 1 chu kỳ; `sin_out`/`cos_out` hợp lệ từ chu kỳ **trước** `done` |
| I05 → tầng ngoài | Độ trễ **cố định 9 chu kỳ**, không phụ thuộc `angle` ⟹ lập lịch tĩnh được |
| 🟥 I05 → tầng ngoài | **Chưa** đạt chu kỳ 10 ns: STA báo WNS `−1,27 ns`. Tầng ngoài phải dùng chu kỳ **dài hơn** (≥ ≈ 11,3 ns sau tổng hợp, và còn dài hơn sau layout) |

## 4. Sơ đồ vòng đời RTL → GDSII (trạng thái **thật**)

```
  ┌──────────────────┐
  │ 0. Charter       │  ✅ ĐÃ CÓ   01_REQUIREMENT/
  └────────┬─────────┘
           ▼
  ┌──────────────────┐
  │ 1. Đặc tả        │  ✅ ĐÃ CÓ   02_SPECIFICATION/
  └────────┬─────────┘
           ▼
  ┌──────────────────┐
  │ 2. RTL           │  ✅ ĐÃ CÓ   rtl/i05_cordic_core.sv
  └────────┬─────────┘
           ▼
  ┌──────────────────┐
  │ 3a. Mô hình      │  ✅ PASS    python_reference_run.log:
  │     chuẩn Python │             "I05 golden reference PASS"
  │                  │             "max sine code error: 5" · "max cosine code error: 4"
  └────────┬─────────┘
           ▼
  ┌──────────────────┐
  │ 3b. Mô phỏng RTL │  ✅ PASS    simulation.log: "I05 RTL TB PASS"
  │     hành vi (L2) │             6 góc, dung sai ±4 mã
  └────────┬─────────┘
           ▼
  ┌──────────────────┐
  │ 4. Tổng hợp      │  ✅ PASS    Yosys 0.33 · 864 cell · 66 FF · 6655,1328 µm²
  │                  │             🟥 VƯỢT dự đoán Charter (350–480 cell)
  └────────┬─────────┘
           ▼
  ┌──────────────────┐
  │ 5. STA sau tổng  │  🟥 KHÔNG ĐẠT  arrival 11,15 ns > required 9,88 ns
  │    hợp           │                WNS −1,27 ns · TNS −13,36 ns
  │                  │                Đường: count[0] → bộ dịch → bộ cộng
  │                  │                        → quantize → sin_out[7]
  └────────┬─────────┘
           ▼
  ┌──────────────────┐
  │ 6. Công suất     │  ✅ ƯỚC LƯỢNG  8,10e-04 W
  │    (ước lượng)   │                ⚠️ TỔ HỢP 59,7 % — khác hẳn I03/I04
  └────────┬─────────┘
           ▼
  ┌──────────────────┐
  │ 7. Gate-level    │  ⬜ CHƯA CHẠY  test_matrix.csv: L4-GATE = "CHUA CHAY"
  │ 8–11. FP/PL/CTS/ │  ⬜ CHƯA CHẠY  cần LibreLane + PDK sky130A
  │       Routing    │                ⚠️ Charter dự phòng "có thể cần 2×1 tile"
  │12. STA sau route │  ⬜ CHƯA CHẠY  ⟵ sẽ còn tệ hơn: thêm ký sinh dây
  │13. SDF sim       │  ⬜ CHƯA CHẠY  L5-SDF = "CHUA CHAY"
  │14. DRC / LVS     │  ⬜ CHƯA CHẠY
  │15. GDSII         │  ⬜ CHƯA CHẠY
  └────────┬─────────┘
           ▼
  ┌──────────────────┐
  │16. Tape-out      │  ⬛ KHÔNG ÁP DỤNG — Charter mục 3
  │17. Đo sau chế tạo│  ⬛ KHÔNG ÁP DỤNG
  └──────────────────┘
```

> 🟥 **Cảnh báo vòng đời — ngược với I04:** ở I04, mô phỏng FAIL mà STA PASS. Ở I05, mô
> phỏng **PASS** mà STA **FAIL**. Hai trường hợp này cùng dạy một bài: **mỗi công cụ chỉ
> trả lời đúng câu hỏi của nó.**
>
> | Công cụ | Trả lời được | **Không** trả lời được |
> |---|---|---|
> | Mô phỏng hành vi | Mạch tính **đúng** không? | Mạch có **kịp** không (zero-delay) |
> | Tổng hợp | RTL biến thành cổng được không? | Đúng hay sai |
> | STA | Có **kịp thời gian** không? | Đúng hay sai |
>
> Phải chạy **cả ba** mới có kết luận. I05 đã chạy cả ba, và kết quả là: **đúng nhưng
> chậm**. Đó là một kết luận có giá trị, không phải một thất bại.

## 5. Các đề lân cận

| Đề | Quan hệ với I05 |
|---|---|
| **D01/D05** — bộ đếm 8 bit / Gray | Sinh `angle` cho I05 trong kiến trúc DDS |
| **D06** — PWM 8 bit | Biến `sin_out`/`cos_out` thành tín hiệu tương tự |
| **I03/I04** — bộ nhân tuần tự | Phương án **thay thế** nếu dùng khai triển Taylor thay CORDIC — sẽ cần bộ nhân, điều CORDIC tránh được (Charter mục 2 câu 1) |
| **B01** — giải mã LED 7 đoạn | Ví dụ về “bảng tra nhỏ”; đối chiếu để thấy vì sao bảng tra 256 mục thì **không** nhỏ |
| **G01/G06** — bộ lọc số | Người tiêu thụ dạng sóng thử do I05 sinh ra |

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
