# I05 · Sơ đồ khối bên trong (Block Diagram)

Vẽ theo **đúng mã RTL** trong `04_IMPLEMENTATION/rtl/i05_cordic_core.sv`. Mọi tên thanh
ghi tra được trong `06_GDSII/synthesis/netlist.v`.

---

## 1. Sơ đồ khối

```
   angle[7:0]                                             start  rst_n  clk
       │                                                    │      │     │
       ▼                                                    ▼      ▼     ▼
 ┌──────────────────────────┐                      ┌──────────────────────┐
 │  GẬP GÓC (tổ hợp)        │                      │  ĐIỀU KHIỂN          │
 │  angle<64  → z=angle     │                      │  state[1:0]  (2 FF)  │
 │  angle<128 → z=128−angle │                      │  count[3:0]  (4 FF)  │
 │  angle<192 → z=angle−128 │                      │  busy, done  (2 FF)  │
 │  còn lại   → z=256−angle │                      └──────┬───────────┬───┘
 │  ⟹ z_init[9:0]          │                       load   │  count==7 │
 │  ⟹ sign_cos, sign_sin   │                              │           │
 └────┬────────────┬────────┘                              │           │
      │ z_init     │ sign_cos/sign_sin                     │           │
      │            └──────────────────────────┐            │           │
      ▼                                        │           │           │
 ┌─────────────┐   ┌──────────────┐  ┌─────────┴──┐        │           │
 │ z_reg[9:0]  │   │ x_reg[15:0]  │  │ y_reg[15:0]│◀───────┘           │
 │  (10 FF)    │   │  (16 FF)     │  │  (16 FF)   │                    │
 └──┬───┬──────┘   └───┬─────┬────┘  └───┬────┬───┘                    │
    │   │              │     │           │    │                        │
    │   │  ┌───────────┘     │           │    └────────┐               │
    │   │  │                 │           │             │               │
    │   │  │       ┌─────────▼───┐   ┌───▼─────────┐   │               │
    │   │  │       │ BỘ DỊCH     │   │ BỘ DỊCH     │   │               │
    │   │  │       │ BIẾN THIÊN  │   │ BIẾN THIÊN  │   │               │
    │   │  │       │  x >>> count│   │  y >>> count│   │               │
    │   │  │       │ (mux2i/mux4)│   │ (mux2i/mux4)│   │               │
    │   │  │       └──────┬──────┘   └──────┬──────┘   │               │
    │   │  │              │ x>>i            │ y>>i     │               │
    │   │  │              │   ┌─────────────┘          │               │
    │   │  │              │   │                        │               │
    │   │  │           ┌──▼───▼──────────┐  ┌──────────▼────────┐      │
    │   │  └──────────▶│ CỘNG/TRỪ 16-BIT │  │ CỘNG/TRỪ 16-BIT   │      │
    │   │              │ x_next = x ∓ y>>i│  │ y_next = y ± x>>i │      │
    │   │              └────────┬────────┘  └─────────┬─────────┘      │
    │   │                       │                     │                 │
    │   │  ┌────────────────────┼─────────────────────┼────────┐        │
    │   │  │ CHỌN CHIỀU: d = (z_reg >= 0) ? +1 : −1   │        │        │
    │   │  └────────────────────┼─────────────────────┼────────┘        │
    │   │                       │                     │                 │
    │   └──────┐                │                     │                 │
    │          ▼                │                     │                 │
    │   ┌──────────────┐        │                     │                 │
    │   │ BẢNG ARCTAN  │        │                     │                 │
    │   │ atan_const   │        │                     │                 │
    │   │ (count[2:0]) │        │                     │                 │
    │   │ 32,19,10,5,  │        │                     │                 │
    │   │  3,1,1,0     │        │                     │                 │
    │   └──────┬───────┘        │                     │                 │
    │          ▼                │                     │                 │
    │   ┌──────────────┐        │                     │                 │
    └──▶│ CỘNG/TRỪ 10b │        │                     │                 │
        │ z_next = z ∓ a│       │                     │                 │
        └──────────────┘        │                     │                 │
                                ▼                     ▼                 ▼
                    ┌───────────────────────────────────────┐    count==7
                    │  quantize_q14():  làm tròn + BÃO HOÀ  │◀──────────┘
                    │  (v±64) >>> 7 ; kẹp về [−128, 127]    │  CHỈ Ở VÒNG CUỐI
                    └───────┬───────────────────┬───────────┘
                            │                   │
                    sign_cos│           sign_sin│
                            ▼                   ▼
                    ┌───────────────┐   ┌───────────────┐
                    │ cos_out[7:0]  │   │ sin_out[7:0]  │
                    │   (8 FF)      │   │   (8 FF)      │
                    └───────────────┘   └───────────────┘
```

> 🟥 **Đường màu đỏ của thiết kế:** `count` → bộ dịch biến thiên → bộ cộng 16-bit →
> `quantize_q14` → `sin_out`. **Tất cả trong MỘT chu kỳ.** Đây chính là đường tới hạn thật
> mà STA chỉ ra, và là nguyên nhân WNS `−1,27 ns`. Phân tích ở §4.

## 2. Bảng ánh xạ cấu trúc RTL → phần cứng sinh ra

| Dòng RTL | Cấu trúc | Phần cứng sinh ra | Bằng chứng netlist |
|---|---|---|---|
| 18 `x_reg, y_reg [15:0]` | thanh ghi | 32 `dfxtp_1` | 16 tên `x_reg[*]`, 16 tên `y_reg[*]` |
| 20 `z_reg [9:0]` | thanh ghi | 10 `dfxtp_1` | 10 tên `z_reg[*]` |
| 21 `count [3:0]` | bộ đếm | 4 `dfxtp_1` | 4 tên `count[*]` |
| 26–32 `enum` + `state` | FSM | 2 `dfxtp_1` | 2 tên `state[*]` |
| 7–8 `sin_out`, `cos_out` | thanh ghi ra | 16 `dfxtp_1` | 8 + 8 |
| 9–10 `busy`, `done` | | 2 `dfxtp_1` | 2 |
| 16 `X_INIT = 16'sd9949` | **hằng số** | **0 cell** — chỉ là hằng nối vào MUX nạp | Không có cell riêng |
| 34–45 `function atan_const` | **bảng tra 8 mục × 10 bit** | Gộp vào MUX toán hạng của bộ cộng `z` | ⬜ **không tách riêng được** — xem §5 |
| **93–94, 97–98** `>>> count` | **BỘ DỊCH BIẾN THIÊN 16-bit ×2** | `mux2i_1` **41** + `mux4_2` **23** + `mux2_1` **13** = **77 mux** | Nhóm cell lớn nhất sau logic cơ bản |
| 93–94, 97–98 `x_reg ∓ …`, `y_reg ±…` | **2 bộ cộng/trừ 16-bit** | chuỗi carry: `maj3_1` | 40 `maj3_1` cho cả ba bộ cộng |
| 95, 99 `z_reg ∓ atan_const(…)` | **1 bộ cộng/trừ 10-bit** | | |
| 92, 96 `if (z_reg >= 0)` | so sánh dấu | **0–1 cell** — chỉ là `z_reg[9]` | Bit dấu, gần như miễn phí |
| 74–90 gập góc | 3 bộ so sánh + 3 bộ trừ 8-bit | `nor2_1`, `a21oi_1`, `nand2_1` trong nhóm 341 cell logic cơ bản | |
| 47–67 `quantize_q14` | làm tròn + **bão hoà** | So sánh `>127`, `<−128`: `nand4_1` ×3, `or4_1`, `o41ai_1`, `o31ai_1` ×11, `nor3_1` ×13 | Các cell **nhiều đầu vào** — đặc trưng của so sánh hằng |
| 139–144 `sign_* ? −q : q` | đổi dấu | bộ trừ 8-bit ×2 | |
| 104–113 `if (!rst_n)` | **reset đồng bộ** | logic trên đường `D` | 66 `dfxtp_1`, **không** có `dfrtp` |

**Tổng: 32+10+4+2+16+2 = 66 FF — khớp chính xác `synth_stat.txt`.**

## 3. Trả lời Charter mục 9: **không có cell nhân nào**

> *“CORDIC chỉ dùng cộng, trừ và dịch bit — không có phép nhân. Xác nhận điều đó trong
> báo cáo sử dụng cell (không có cell nhân nào).”*

Rà **toàn bộ 55 loại cell** trong `06_GDSII/physical_report.md` §2:

| Nhóm chức năng | Có mặt? | Cell đại diện |
|---|:-:|---|
| Cổng logic cơ bản (NAND/NOR/INV/AND/OR) | ✅ | `nand2_1` 81, `nor2_1` 106, `clkinv_1` 35, `and2_0` 27 |
| Cổng AND-OR-INVERT phức hợp | ✅ | `a21oi_1` 90, `o21ai_0` 64, `a22oi_1` 18 … |
| XOR / XNOR (hàm SUM của bộ cộng) | ✅ | `xnor2_1` 54, `xor2_1` 17 |
| **MAJ3 (hàm carry của bộ cộng)** | ✅ | `maj3_1` **40** |
| **MUX (bộ dịch biến thiên)** | ✅ | `mux2i_1` 41, `mux4_2` 23, `mux2_1` 13 |
| Flip-flop | ✅ | `dfxtp_1` 66 |
| Đệm / cách ly | ✅ | `lpflow_isobufsrc_1` 14, `lpflow_inputiso1p_1` 13 |
| **Cell nhân / DSP / MAC** | ❌ **KHÔNG CÓ** | — |
| **Macro bộ nhớ / ROM** | ❌ **KHÔNG CÓ** | `synth_stat.txt`: `Number of memories: 0` |
| **Latch** | ❌ **KHÔNG CÓ** | Không có `dlxtp`/`dlatch` |

✅ **Khẳng định của Charter được xác nhận bằng bảng cell thật.** Toàn bộ “phép nhân” của
thuật toán được hiện thực bằng **77 cell MUX** (dịch) + **40 cell MAJ3** (carry) + **71
cell XOR/XNOR** (sum). Đó chính là ý nghĩa của câu *“CORDIC đổi phép nhân thành phép dịch
và cộng”* — và ở đây nó được nhìn thấy trực tiếp trên netlist, không phải chỉ nói suông.

> ℹ️ Bổ sung cho chặt chẽ: thư viện `sky130_fd_sc_hd` **không có** cell nhân nào cả — nó là
> thư viện standard cell, không phải thư viện DSP. Vì vậy khẳng định trên mạnh hơn nếu nói
> kèm: *“nếu RTL có viết `*`, Yosys sẽ **tổng hợp ra một mảng nhân bằng standard cell** —
> và ta sẽ thấy số `maj3_1` tăng vọt lên hàng trăm, chứ không phải thấy một cell tên
> `mult`.”* Con số 40 `maj3_1` (vừa đủ cho ba bộ cộng 16+16+10 bit) là bằng chứng rằng
> điều đó **không** xảy ra.

## 4. Khối con nào nằm trên đường tới hạn — và vì sao slack âm

Từ `06_GDSII/sta/timing_report_max.txt` và `netlist.v`:

```
  _1655_ = count[0]  (dfxtp_1)                     ← STARTPOINT
     │ 1,45 ns  (clk→Q) — FANOUT 42, SLEW 1,69 ns  🟥 rất nặng
     ▼
  _0834_ mux2i_1 → _0835_ o21a_1 → _0917_ mux4_2   ← BỘ DỊCH BIẾN THIÊN, tới 2,44 ns
     ▼
  _0922_ … _0934_  : 13 × maj3_1                   ← CHUỖI CARRY bộ cộng 16-bit
     │                 ≈ 0,37 ns/tầng, tới 7,27 ns
     ▼
  _0935_ a21oi_1 → _0957_ o21ai_0 → _0959_ xor2_1  ← hàm SUM
     ▼
  _1014_ nor3_1 → _1015_ o21ai_0 → _1021_ nand4_1  ← 🟥 SO SÁNH BÃO HOÀ
     ▼                                                (quantize_q14: q>127? q<−128?)
  _1038_ o31ai_1 → _1041_ nor3b_1 → _1042_ o21ai_0
     ▼
  _1065_ or4_1 → _1080_ o41ai_1 → _1081_ a21oi_1   ← 🟥 tiếp tục logic bão hoà
     ▼
  _1084_ o21a_1
     ▼
  _1603_ = sin_out[7]  (dfxtp_1)                   ← ENDPOINT
                      arrival 11,15 ns  ·  required 9,84 ns  ·  slack −1,27 ns
```

| Khối con | Trên đường tới hạn? | Đóng góp ước tính |
|---|:-:|---|
| **`count[0]` clk→Q (fanout 42)** | ✅ | **1,45 ns / 11,15 ns ≈ 13 %** — một flip-flop đơn lẻ! |
| **Bộ dịch biến thiên** (`mux2i`, `mux4_2`) | ✅ | 1,45 → 2,44 ns ≈ **0,99 ns ≈ 9 %** |
| **Chuỗi carry bộ cộng 16-bit** | ✅ | 2,44 → 7,27 ns ≈ **4,83 ns ≈ 43 %** |
| **`quantize_q14` (làm tròn + bão hoà)** | ✅ | 7,27 → 11,15 ns ≈ **3,88 ns ≈ 35 %** |
| Bảng arctan / bộ cộng `z` | ❌ | Đường song song, ngắn hơn |
| Gập góc | ❌ | Chỉ hoạt động ở `S_IDLE` |
| FSM | ❌ | Rất ngắn |

### Ba nguyên nhân slack âm, xếp theo mức đóng góp

| # | Nguyên nhân | Đóng góp | Chữa thế nào (⚠️ chưa áp dụng) |
|---|---|---:|---|
| **1** | **`quantize_q14` nằm TRONG vòng lặp.** RTL gọi `quantize_q14(x_next)` — tức áp làm tròn + bão hoà lên kết quả **tổ hợp** của vòng 8, cùng chu kỳ | ≈ 3,88 ns (**35 %**) | Chuyển việc lượng tử hoá sang `S_DONE`, dùng `x_reg`/`y_reg` **đã chốt**. `S_DONE` vốn đã tồn tại ⟹ **không tốn thêm chu kỳ nào** |
| **2** | **Bộ dịch biến thiên `>>> count`** với `count` là thanh ghi fanout **42** | ≈ 2,44 ns (**22 %**) | Trải vòng lặp (dịch thành **hằng số**, 0 cell), hoặc đăng ký sẵn `count` dạng one-hot để giảm mức mux |
| **3** | Chuỗi carry bộ cộng 16-bit | ≈ 4,83 ns (**43 %**) | Khó giảm mà không đổi kiến trúc bộ cộng (carry-lookahead) — **ngoài phạm vi** |

> 🔎 **Kết luận quan trọng:** nếu chỉ chuyển `quantize_q14` sang `S_DONE` (nguyên nhân 1),
> đường tới hạn ước giảm ≈ 3,88 ns ⟹ arrival ≈ **7,3 ns**, slack trở thành **dương ≈ +2,5 ns**.
> Đây là một sửa đổi **một khối, không tốn chu kỳ, không tốn diện tích đáng kể** — tỉ lệ
> lợi ích / rủi ro cao nhất trong toàn hồ sơ. Vẫn cần chạy lại STA để xác nhận;
> con số ở trên là **ước tính từ phân rã độ trễ**, không phải kết quả đo. Xem
> `tradeoff.md` §7.

## 5. Bảng arctan tốn bao nhiêu cell — Charter mục 2 câu 3

⬜ **Không tách riêng được từ số liệu hiện có.** Lý do: `atan_const()` là một `function`
tổ hợp được **gọi bên trong `always_comb`**, nên Yosys **hoà tan** nó vào MUX toán hạng
của bộ cộng `z`. Trong `netlist.v` không tồn tại ranh giới module hay tên instance nào
tương ứng với bảng.

**Ước lượng trần trên (chỉ để định hướng, KHÔNG phải số đo):** bảng là 8 mục × 10 bit,
nhưng các giá trị `32, 19, 10, 5, 3, 1, 1, 0` chỉ chiếm 6 bit thấp và có nhiều bit 0 chung
⟹ sau tối ưu hằng, phần logic thực tế nhỏ hơn nhiều so với một ROM 80 bit.

**Cách lấy số thật** (chưa chạy):

```bash
# 1. Tach atan_const thanh mot module doc lap:
#    module atan_rom (input logic [2:0] idx, output logic signed [9:0] v);
# 2. Tong hop RIENG module do, cung thu vien va cung script:
yosys -p "read_verilog -sv atan_rom.sv; synth -top atan_rom; \
          abc -liberty sky130_fd_sc_hd__tt_025C_1v80.lib; \
          stat -liberty sky130_fd_sc_hd__tt_025C_1v80.lib"
# 3. Doc "Number of cells" va "Chip area" -> do la chi phi cua bang arctan
# 4. Doi chieu: tong hop lai I05 voi 'keep_hierarchy' de giu ranh gioi module
```

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
