# I05 · Đặc tả chức năng (Functional Specification)

> 🟡 **CẢNH BÁO ĐỐI CHIẾU RTL ↔ CHARTER — đọc trước khi dùng tài liệu này**
>
> | Hạng mục Charter | Trạng thái | Bằng chứng |
> |---|---|---|
> | Mục 1 — *Bộ tính sin và cos bằng CORDIC 8-bit* | ✅ **THOẢ** | RTL hiện thực tường minh 8 vòng CORDIC chế độ quay; `simulation.log`: `I05 RTL TB PASS` |
> | Mục 4 — ánh xạ chân Tiny Tapeout (`ui_in[7:0]`=góc, `uio_in[0]`=bắt đầu, `uo_out`=sin, `uio_out`=cos) | ⚠️ **CHƯA THOẢ** | RTL **không có** cổng nào tên `ui_in`/`uio_in`/`uo_out`/`uio_out`. Cổng thật: `angle`, `start`, `sin_out`, `cos_out`, `busy`, `done` |
> | Mục 10 — “dấu hiệu làm đúng ≈ 27–30 ô nhớ” | ⚠️ **LỆCH** | Đo được **66 FF** — hơn gấp đôi. Phân tích ở §9 |
> | Metadata — quy mô ~350–480 cell | 🟥 **VƯỢT** | Đo được **864 cell** — **vượt 80 %** so với cận trên. Charter đã dự phòng *“có thể cần 2×1 tile”*, và số liệu xác nhận điều đó |
> | **Ràng buộc thời gian** (`design.sdc`, chu kỳ 10 ns) | 🟥 **KHÔNG ĐẠT** | STA: **WNS = −1,27 ns**, **TNS = −13,36 ns**. Đây là đề **duy nhất** trong nhóm I có slack âm. Phân tích nguyên nhân ở `datapath.md` §5 |
>
> **Kết luận cảnh báo:** khối **đúng chức năng** nhưng **chưa đạt ràng buộc thời gian giả
> định** và **vượt quy mô dự kiến**. REQ-I05-002 (ánh xạ chân) và REQ-I05-004 (quy mô) phải
> đánh dấu **CHƯA THOẢ**. **Không tự sửa RTL** — cần giảng viên duyệt.

---

## 1. Phát biểu chức năng ở mức toán học

Khối nhận **một góc 8 bit** và trả về **sin và cos** của góc đó, cả hai ở dạng số nguyên
có dấu 8 bit.

```
  Quy ước góc:   angle ∈ [0, 255]  biểu diễn  θ = angle · 360°/256 = angle · 1,40625°
                 (một vòng tròn đầy đủ chia thành 256 phần — "brad", binary radian)

  Quy ước đầu ra: sin_out ≈ round(128 · sin θ)  ,  cos_out ≈ round(128 · cos θ)
                  kẹp về [−128, +127]           (định dạng Q0.7 có dấu)
```

| Đặc điểm | Giá trị |
|---|---|
| Độ phân giải góc | **1,40625°** — chỉ 256 góc rời rạc tồn tại |
| Độ phân giải biên độ | `1/128 ≈ 0,0078` |
| `+1,0` biểu diễn thành | `127` (không phải 128 — bị kẹp) |
| `−1,0` biểu diễn thành | `−128` |

> ⚠️ **Sai số là MỘT PHẦN CỦA ĐẶC TẢ, không phải lỗi.** Charter mục 10 nói thẳng:
> *“Sai số là một PHẦN CỦA KẾT QUẢ, không phải lỗi — phải lập bảng sai số, không được
> giấu.”* Vì vậy §7 dưới đây là một mục **bắt buộc**, không phải phụ lục.

## 2. Cơ chế CORDIC — bảng hành vi bắt buộc

Tên đề **chỉ định kiến trúc**: *“bằng CORDIC”*. RTL bắt buộc mô tả tường minh vòng lặp
quay; viết `sin_out = $sin(...)` hay dùng bảng tra 256 mục là **sai đề**.

### 2.1 Ba phương trình của một vòng lặp

```
   d_i = +1 nếu z_i ≥ 0, ngược lại −1        (chọn chiều quay)

   x_{i+1} = x_i − d_i · (y_i >> i)
   y_{i+1} = y_i + d_i · (x_i >> i)
   z_{i+1} = z_i − d_i · atan_table[i]
```

Điểm cốt lõi: **không có phép nhân nào.** `(y_i >> i)` là phép dịch — nó thay cho phép
nhân với `2^(−i)`. Đây chính là điều Charter mục 9 đòi xác nhận trên báo cáo cell.

### 2.2 Bảng hằng số arctan trong RTL (dòng 34–45)

| `i` | `atan_const(i)` | Giá trị lý thuyết `atan(2^−i)·256/2π` | Góc tương ứng |
|---:|---:|---:|---|
| 0 | **32** | 32,00 | 45,000° |
| 1 | **19** | 18,90 | 26,565° |
| 2 | **10** | 9,98 | 14,036° |
| 3 | **5** | 5,07 | 7,125° |
| 4 | **3** | 2,55 | 3,576° |
| 5 | **1** | 1,27 | 1,790° |
| 6 | **1** | 0,64 | 0,895° |
| 7 | **0** | 0,32 | 0,448° |

Bảng này khớp chính xác với `ATAN` mà mô hình chuẩn tính ra
(`reference_model.py` dòng 7–8, và `test_constants` kiểm `ATAN == [32,19,10,5,3,1,1,0]`).

> 🔎 **Hai quan sát quan trọng, và chúng giải thích toàn bộ sai số:**
>
> 1. **Mục cuối bằng 0.** Vòng thứ 8 **không** hiệu chỉnh góc nữa (`z` không đổi), nhưng
>    **vẫn quay** `x`, `y` một lượng `2^−7`. Nghĩa là vòng 8 chỉ còn tác dụng làm mịn biên
>    độ, không làm mịn góc.
> 2. **Tổng bảng = 71**, phủ được `z_init ∈ [0, 64]` — đủ cho một phần tư vòng tròn. Nhưng
>    vì bảng được **làm tròn về số nguyên**, góc dư cuối cùng có thể còn tới ≈ 1 LSB góc
>    = 1,40625°, tương ứng sai số biên độ tới `128·sin(1,4°) ≈ 3` mã.

### 2.3 Gập một phần tư vòng tròn (dòng 74–90)

CORDIC chỉ hội tụ trong khoảng `|z| ≲ 99,9°`. RTL vì vậy gập góc về một phần tư rồi khôi
phục dấu ở cuối:

| `angle` | Góc | `z_init` | `sign_cos` | `sign_sin` | Ý nghĩa |
|---|---|---|:-:|:-:|---|
| `0 … 63` | `[0°, 90°)` | `angle` | 0 (`+`) | 0 (`+`) | Góc phần tư I |
| `64 … 127` | `[90°, 180°)` | `128 − angle` | **1 (`−`)** | 0 (`+`) | II: `cos` đổi dấu |
| `128 … 191` | `[180°, 270°)` | `angle − 128` | **1 (`−`)** | **1 (`−`)** | III: cả hai đổi dấu |
| `192 … 255` | `[270°, 360°)` | `256 − angle` | 0 (`+`) | **1 (`−`)** | IV: `sin` đổi dấu |

Nhờ vậy `z_init` luôn thuộc `[0, 64]`, tức `[0°, 90°]` — nằm gọn trong miền hội tụ.

### 2.4 Bù hệ số khuếch đại (dòng 16)

Mỗi vòng CORDIC không chỉ quay mà còn **kéo dài** vector một hệ số
`sqrt(1 + 2^(−2i))`. Sau 8 vòng, tích số đó là `K₈ ≈ 1,6467`. RTL bù trước bằng cách khởi
tạo:

```systemverilog
localparam logic signed [15:0] X_INIT = 16'sd9949;   //  = round(2^14 / K₈)
```

Mô hình chuẩn tính độc lập và `test_constants` kiểm `X_INIT == 9949` — **khớp**. Đây là
một hằng số **không thể đoán**; việc nó khớp là bằng chứng tốt rằng RTL và mô hình chuẩn
nói về cùng một thuật toán.

## 3. Định dạng số bên trong

| Đại lượng | Độ rộng | Định dạng | Ghi chú |
|---|---:|---|---|
| `x_reg`, `y_reg` | 16 | **Q1.14** có dấu (`2^14` = 1,0) | Đủ dải cho `x ≤ 16384` và cho `K₈` |
| `z_reg` | 10 | brad có dấu (`256` = 360°) | Cần 10 bit vì `z` có thể âm và tràn nhẹ trong lúc hiệu chỉnh |
| `angle` | 8 | brad **không dấu** | |
| `sin_out`, `cos_out` | 8 | **Q0.7** có dấu (`128` = 1,0) | Kẹp về `[−128, 127]` |

Hàm `quantize_q14` (dòng 47–67) làm hai việc: **làm tròn** từ Q1.14 về Q0.7 (dịch phải 7
bit) và **kẹp bão hoà**.

## 4. Định nghĩa chính xác từng tín hiệu ra

Ký hiệu: `C0` là cạnh clock lên có `state == S_IDLE` và `start == 1`.

| Tín hiệu | Định nghĩa |
|---|---|
| `sin_out[7:0]` | Thanh ghi có dấu. Nạp **duy nhất** tại `C8` từ `y_next` (giá trị **tổ hợp** của vòng 8). Giữa hai giao dịch giữ kết quả trước. Sau reset = 0 |
| `cos_out[7:0]` | Như trên, từ `x_next` |
| `busy` | `1` trên `[C0, C8)` |
| `done` | Xung **đúng một chu kỳ**, cao trên `[C9, C10)` |

> ⚠️ **Chi tiết kiến trúc có hậu quả lớn:** `sin_out`/`cos_out` được tính từ `x_next`/`y_next`
> — tức **kết quả tổ hợp chưa qua thanh ghi** của vòng 8 — rồi mới đi qua `quantize_q14`
> (làm tròn + bão hoà) và khâu đổi dấu, **tất cả trong cùng một chu kỳ**. Đây chính là
> nguyên nhân slack âm (xem `datapath.md` §5).

## 5. Trạng thái sau reset và độ trễ

`rst_n` là **reset đồng bộ** (`always_ff @(posedge clk)`, không có `negedge rst_n`).

| Đại lượng | Giá trị |
|---|---|
| Sau reset | `state = S_IDLE`, `x_reg = y_reg = z_reg = 0`, `count = 0`, `sin_out = cos_out = 0`, `busy = done = 0` |
| Rời `S_IDLE` | `start == 1` lấy mẫu tại cạnh clock lên; nạp `x_reg ← 9949`, `y_reg ← 0`, `z_reg ← z_init` |
| `start` → `done` | **9 chu kỳ** (1 nạp + 8 vòng) |
| Một giao dịch trọn vẹn | **10 chu kỳ** |
| `sin_out`/`cos_out` hợp lệ từ | `C8` — sớm hơn `done` một chu kỳ |
| Phụ thuộc dữ liệu? | **Không** — mọi góc đều tốn đúng 10 chu kỳ |

> Bằng chứng: `simulation.log` ghi `$finish called at 615`. Testbench 6 ca, chu kỳ 10 ns,
> `C0` ca đầu ở `t = 25 ns` ⟹ `615 = 115 + 5·100` ⟹ 9 chu kỳ tới `done`, 10 chu kỳ/giao
> dịch. Xem `03_ARCHITECTURE/timing_diagram.md` §4.

## 6. Tính chất bất biến (Invariants)

| ID | Phát biểu | Ghi chú |
|---|---|---|
| **INV-1** | `done |=> !done` | Đã có trong `testbench/properties.sv` |
| **INV-2** | `sin_out`, `cos_out`, `busy`, `done` không chứa `X`/`Z` sau reset | Đã có trong `properties.sv` |
| **INV-3** | **Bất biến CORDIC:** `x_i² + y_i² = K_i² · X_INIT²` — độ dài vector chỉ thay đổi theo hệ số đã biết, không bao giờ theo dữ liệu | Bất biến mạnh nhất để bắt lỗi dịch/dấu |
| **INV-4** | `|z_i|` giảm đơn điệu **cho tới** khi `atan_table[i] = 0`; sau vòng 7 thì `z` đứng yên | Hệ quả của bảng làm tròn (§2.2) |
| **INV-5** | `−128 ≤ sin_out, cos_out ≤ 127` với mọi `angle` | Đảm bảo bởi khâu kẹp trong `quantize_q14` |
| **INV-6** | `sin_out² + cos_out² ≈ 128²` (trong phạm vi sai số lượng tử) | Kiểm định hình học; **chưa** có assertion nào kiểm |
| **INV-7** | Mọi giao dịch tốn đúng 8 vòng, không phụ thuộc `angle` | |
| **INV-8** | `start` bị bỏ qua khi `state != S_IDLE` | |
| **INV-9** | `z_init ∈ [0, 64]` với mọi `angle ∈ [0, 255]` | Đảm bảo bởi khâu gập (§2.3); là điều kiện hội tụ |
| **INV-10** | `x_reg`, `y_reg` không tràn 16 bit: `|x|, |y| ≤ K₈ · 9949 ≈ 16383` | Biên sát — chỉ còn 1 mã dự phòng |

> 💡 INV-10 rất sát biên. `K₈ · 9949 = 1,6467 × 9949 ≈ 16384`, trong khi 16 bit có dấu chỉ
> chứa tới `32767`. Biên an toàn thực tế là **2×**, nhưng nếu ai đó tăng số vòng lặp mà
> **không** tính lại `X_INIT` thì `x_reg` sẽ tràn. Đây là chỗ đáng kiểm bằng assertion.

## 7. Sai số — phần **bắt buộc** của đặc tả

### 7.1 Bốn nguồn sai số, tách riêng

| # | Nguồn | Độ lớn | Có thể giảm bằng gì |
|---|---|---|---|
| **E-1** | **Số vòng hữu hạn** (8 vòng) | Góc dư ≤ 1 LSB góc = 1,40625° ⟹ biên độ ≈ 3 mã | Tăng số vòng — **nhưng vô ích** nếu không tăng độ rộng bảng arctan |
| **E-2** | **Bảng arctan bị làm tròn về số nguyên** | Mục `i=7` thành **0** ⟹ vòng 8 mất tác dụng hiệu chỉnh góc | Tăng độ rộng `z` và bảng (ví dụ Q10.4) |
| **E-3** | **Lượng tử hoá đầu ra** Q1.14 → Q0.7 | ≤ 0,5 mã | Tăng độ rộng đầu ra |
| **E-4** | **Kẹp bão hoà** tại `+127` | `sin 90° = 1,0` phải thành `127`, sai 1 mã theo định nghĩa | Không thể — là hệ quả của định dạng Q0.7 |

### 7.2 Số liệu sai số **đã đo được**

`05_VERIFICATION/python_reference_run.log`:

```
I05 golden reference PASS
max sine code error: 5
max cosine code error: 4
```

Nghĩa là trên **toàn bộ 256 góc**, so với `round(128·sin θ)` và `round(128·cos θ)`:

| Đại lượng | Giá trị đo |
|---|---:|
| Sai số **lớn nhất** của `sin` | **5** mã ≈ **3,9 %** của toàn thang |
| Sai số **lớn nhất** của `cos` | **4** mã ≈ **3,1 %** |

Bảng sai số chi tiết theo từng góc: `03_ARCHITECTURE/tradeoff.md` §4.

> 🟡 **Sắc thái phải nêu:** hai con số trên là của **mô hình chuẩn Python**, không phải
> của RTL. Hai bên **không bit-exact** — chúng dùng quy tắc làm tròn khác nhau ở hai
> trường hợp (giá trị âm, và giá trị đúng ở nửa đơn vị). Phân tích đầy đủ ở
> `corner_cases.md` §6. Sai số của **chính RTL** trên đủ 256 góc: ⬜ **chưa đo**.

### 7.3 Sai số ở các góc Charter mục 8 đòi

Testbench kiểm 6 góc với dung sai `±4` mã (dòng 40–46) và **PASS**:

| `angle` | Góc | `sin` kỳ vọng | `cos` kỳ vọng | Dung sai | Kết quả |
|---:|---|---:|---:|---|---|
| 0 | 0° | 0 | 127 | ±4 | ✅ PASS |
| 64 | 90° | 127 | 0 | ±4 | ✅ PASS |
| 128 | 180° | 0 | −128 | ±4 | ✅ PASS |
| 192 | 270° | −128 | 0 | ±4 | ✅ PASS |
| 32 | 45° | 91 | 91 | ±4 | ✅ PASS |
| 224 | 315° | −91 | 91 | ±4 | ✅ PASS |

⚠️ Charter mục 8 đòi các góc **30°, 45°, 60°**. Trong hệ brad, 30° và 60° **không** rơi
đúng vào một mã: `30° → 21,33` và `60° → 42,67`. Testbench chọn 4 góc phần tư + 45° +
315° thay thế. Đây là một **lệch so với Charter** cần ghi nhận — xem `corner_cases.md` §2.

## 8. Điều kiện biên và hành vi không xác định

| Tình huống | Hành vi |
|---|---|
| `angle = 0` | `z_init = 0`; vòng 1 quay `+45°` rồi các vòng sau quay ngược lại. Kết quả `cos ≈ 127`, `sin` **không** đúng bằng 0 (sai vài mã) — đây là hành vi đúng của CORDIC, không phải lỗi |
| `angle = 64` (90°) | `z_init = 128 − 64 = 64`; `sign_cos = 1` ⟹ `cos_out = −quantize(x_next)`. Vì `x_next` gần 0 và có thể **hơi âm**, `cos_out` có thể là một số dương nhỏ thay vì 0 |
| `angle = 128` (180°) | `z_init = 0`, cả hai dấu âm ⟹ `cos_out ≈ −127` (không phải `−128`) |
| `angle = 192` (270°) | `z_init = 64`, `sign_sin = 1` ⟹ `sin_out ≈ −127` |
| `quantize_q14` nhận `q = −128` rồi bị đổi dấu | `−(−128)` trong 8 bit **quay vòng** về `−128`. Trường hợp này **không** xảy ra với dữ liệu hợp lệ (vì `|x|, |y| < 16384 + 64`), nhưng là bẫy cần biết |
| `start` cao liên tục | Chạy lần lượt từng giao dịch (INV-8) |
| `start` phát lại tại `C9` | **Bị nuốt lặng lẽ** — xem `control.md` §4 |
| `rst_n` xuống mà clock đứng yên | **Không có tác dụng** (reset đồng bộ) |
| `angle` đổi sau `C0` | Không ảnh hưởng — `z_init` đã chốt vào `z_reg` |
| `state = 2'b11` | `default` đưa về `S_IDLE` |

## 9. Vì sao đo được 66 flip-flop và 864 cell

### 9.1 Flip-flop

| Thanh ghi | Bit | Netlist xác nhận |
|---|---:|:-:|
| `x_reg[15:0]` | 16 | ✅ 16 |
| `y_reg[15:0]` | 16 | ✅ 16 |
| `z_reg[9:0]` | 10 | ✅ 10 |
| `cos_out[7:0]` | 8 | ✅ 8 |
| `sin_out[7:0]` | 8 | ✅ 8 |
| `count[3:0]` | 4 | ✅ 4 |
| `state[1:0]` | 2 | ✅ 2 |
| `busy`, `done` | 2 | ✅ 2 |
| **Tổng** | **66** | ✅ khớp `synth_stat.txt` |

Charter dự đoán `3×8 (x, y, z) + 3 ≈ 27–30`. Khoảng chênh đến từ ba lựa chọn: `x`, `y` dùng
**16 bit Q1.14** thay vì 8 bit (+16 FF), `z` dùng **10 bit** thay vì 8 (+2 FF), và có **hai
thanh ghi ra riêng** `sin_out`/`cos_out` (+16 FF). Cả ba đều có lý do (độ chính xác và giao
diện bền), nhưng phải nói ra.

### 9.2 Cell — vì sao **864**, vượt 80 % dự đoán

| Nhóm cell | Số lượng | Thuộc phần nào |
|---|---:|---|
| `mux2i_1` 41 + `mux4_2` 23 + `mux2_1` 13 = **77 mux** | 77 | **Bộ dịch biến thiên** `>>> count` cho `x` và `y` (16 bit × 2) |
| `maj3_1` | **40** | Chuỗi carry của **ba** bộ cộng: `x_next` (16 bit), `y_next` (16 bit), `z_next` (10 bit) |
| `xnor2_1` 54 + `xor2_1` 17 | 71 | Hàm SUM của ba bộ cộng + logic so sánh |
| `nor2_1` 106 + `a21oi_1` 90 + `nand2_1` 81 + `o21ai_0` 64 | 341 | Logic gập góc, chọn chiều, làm tròn, bão hoà |
| `dfxtp_1` | 66 | Thanh ghi |
| Còn lại | ≈ 269 | Đệm, cách ly, cell phức hợp |

⟹ Nguồn tốn kém **không** phải CORDIC “về nguyên tắc”, mà là **hai bộ dịch biến thiên 16
bit** (vì `count` thay đổi mỗi vòng) cộng với **ba bộ cộng chạy song song mỗi chu kỳ**.
Một hiện thực **trải vòng lặp** (unroll) sẽ dùng dịch **hằng số** (0 cell) nhưng cần 8 bản
sao bộ cộng — đánh đổi bàn ở `tradeoff.md` §6.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
