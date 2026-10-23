# I05 · Bối cảnh ứng dụng



| | |
|---|---|
| Mã đề | **I05** |
| Tên đề | Bộ tính sin và cos bằng CORDIC 8-bit |
| Nhóm đề | I · Số học nâng cao |
| Độ khó | Trung bình |
| Loại mạch | **Tuần tự** |
| Quy mô ước lượng (Charter) | ~350–480 cell · 1×1 tile hoặc 2×1 |
| Nguồn gốc | Project Charter — I05, mục 1 |

---

## 1. Mục tiêu và bối cảnh ứng dụng

Trích nguyên văn Charter mục 1:

> Phân tích khối số “Bộ tính sin và cos bằng CORDIC 8-bit” ở mức khối. Bối cảnh ứng dụng: Khối tính sin/cos để tạo dạng sóng trong bộ phát tín hiệu thử, không dùng bảng tra lớn.

## 2. Vị trí khối I05 trong hệ thống

```
   ┌──────────────┐      ┌──────────────────────────────┐      ┌──────────────┐
   │  Nguồn tín   │─────▶│      ►►► KHỐI I05 ◄◄◄        │─────▶│  Tầng tiêu   │
   │  hiệu / dữ   │      │  Bộ tính sin và cos bằng CORD │      │  thụ kết quả │
   │  liệu vào    │      │  Loại mạch: Tuần tự          │      │              │
   └──────────────┘      └──────────────────────────────┘      └──────────────┘
```

> Sơ đồ chi tiết có chú thích: `03_ARCHITECTURE/system_diagram.md`.

## 3. Phân loại analog / digital / mixed

| Khối | Phân loại | Ghi chú |
|---|---|---|
| Cảm biến / nguồn tín hiệu vật lý (nếu có) | Analog | Đại lượng liên tục |
| Chuyển đổi ADC/DAC (nếu có) | Mixed-signal | Ranh giới analog–số |
| **I05 — Bộ tính sin và cos bằng CORDIC 8-bit** | **Digital, tuần tự** | Có ô nhớ, hoạt động theo cạnh clock |
| Tầng xử lý phía sau | Digital | Tiêu thụ kết quả của I05 |

Bằng chứng cho dòng phân loại của I05: tổng hợp thật cho **66 flip-flop**
(`06_GDSII/synthesis/synth_stat.txt`).

---

**Truy vết:** yêu cầu sinh từ tài liệu này được đánh số `REQ-I05-0xx` trong
`01_REQUIREMENT/requirements.md`, và truy vết đến bằng chứng trong `07_TRACEABILITY/RTM.csv`.

*Phiên bản: v1.0 · Ngày: 2026-09-24*
