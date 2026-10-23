# I05 · Đường dữ liệu (Datapath)

---

## 1. Đặc trưng: **ba** đường dữ liệu chạy song song, ràng buộc chéo

Khác với I03 (một tích luỹ) và I04 (một thanh ghi trạng thái), datapath của I05 có **ba
đường độc lập về cấu trúc nhưng phụ thuộc chéo về dữ liệu**:

```
   ┌─────────── vòng hồi tiếp x (1 chu kỳ) ──────────┐
   │                                                  │
   ▼            ┌──────────────┐                      │
 [x_reg] ──┬───▶│ CỘNG/TRỪ 16b │──▶ x_next ───────────┘
           │    └──────▲───────┘
           │           │ y >>> count
           │    ┌──────┴───────┐
           └───▶│ BỘ DỊCH ×2   │◀──────────────┐
                └──────┬───────┘               │
                       │ x >>> count           │
   ┌────────────┐      ▼                       │
   │            │  ┌──────────────┐            │
   ▼            └─▶│ CỘNG/TRỪ 16b │──▶ y_next ─┘
 [y_reg] ───────────└──────────────┘
                                          ▲
   ┌─────────── vòng hồi tiếp z ─────────┐ │ chiều quay d
   ▼            ┌──────────────┐          │ │
 [z_reg] ──────▶│ CỘNG/TRỪ 10b │──▶ z_next┘ │
                └──────▲───────┘            │
                       │ atan_const(count)  │
                 [BẢNG ARCTAN]              │
                       │                    │
                 z_reg[9] (bit dấu) ────────┘
```

Ba quan sát quan trọng:

1. **`x_next` cần `y_reg`, `y_next` cần `x_reg`** — chéo nhau. RTL dùng đúng giá trị
   **cũ** cho cả hai (dòng 93–94 đều đọc `x_reg`/`y_reg`, không đọc `x_next`). Nếu viết
   nhầm `y_next = y_reg + (x_next >>> count)` thì thuật toán sai hoàn toàn và **chuỗi
   carry sẽ nối tiếp hai bộ cộng** — đường tới hạn gấp đôi.
2. **`z_reg[9]` (bit dấu) điều khiển cả ba đường.** Đây là tín hiệu điều khiển sinh từ dữ
   liệu, giống `mplier_reg[0]` của I03 — nhưng ở đây nó điều khiển **42 bit** dữ liệu.
3. **Đường `z` là đường ngắn nhất** (bộ cộng 10 bit) nhưng nó **quyết định** hai đường kia.
   Vì vậy `z_reg[9]` phải ổn định sớm — và nó ổn định ngay sau clk→Q, nên không thành vấn đề.

## 2. Bảng các đường dữ liệu

| Đường | Độ rộng | Từ | Đến | Bản chất |
|---|---:|---|---|---|
| `angle[7:0]` | 8 | cổng vào | logic gập góc | Góc vào, brad không dấu; chỉ lấy mẫu tại `C0` |
| `z_init[9:0]` | 10 | logic gập (tổ hợp) | `z_reg` tại `C0` | Góc đã gập về `[0, 64]` |
| `sign_cos`, `sign_sin` | 1+1 | logic gập (**tổ hợp**) | khâu đổi dấu tại `C8` | ⚠️ **Không** được đăng ký — xem §6 |
| `x_reg[15:0]` | 16 | thanh ghi | bộ dịch + bộ cộng | Q1.14, toạ độ `x`; nạp `X_INIT = 9949` |
| `y_reg[15:0]` | 16 | thanh ghi | bộ dịch + bộ cộng | Q1.14, toạ độ `y`; nạp `0` |
| `z_reg[9:0]` | 10 | thanh ghi | bộ cộng `z` + **chọn chiều** | Góc dư; bit `[9]` là tín hiệu điều khiển |
| `x_reg >>> count` | 16 | **bộ dịch biến thiên** | bộ cộng `y` | Thay cho phép nhân `× 2^−i` |
| `y_reg >>> count` | 16 | **bộ dịch biến thiên** | bộ cộng `x` | Như trên |
| `atan_const(count[2:0])` | 10 | **bảng hằng** | bộ cộng `z` | 8 hằng số, hoà vào MUX |
| `x_next`, `y_next` | 16 | bộ cộng (**tổ hợp**) | `x_reg`/`y_reg`, **và** `quantize_q14` | 🟥 Đi thẳng vào bộ lượng tử hoá ở vòng cuối |
| `count[3:0]` | 4 | bộ đếm | **điều khiển bộ dịch** + so `==7` | 🟥 Fanout **42** — nút thắt |
| `sin_out`, `cos_out` | 8+8 | `quantize_q14` + đổi dấu | cổng ra | Q0.7 có dấu |

## 3. Vì sao `x_reg`/`y_reg` phải 16 bit trong khi đầu ra chỉ 8 bit

Đây là câu hỏi hay bị bỏ qua, và nó giải thích phần lớn khoảng chênh 66 FF ↔ 27–30 FF.

| Lý do | Chi tiết |
|---|---|
| **Sai số tích luỹ qua 8 vòng** | Mỗi vòng có một phép dịch phải làm mất bit thấp. Với 8 vòng, ta mất tới 8 bit độ chính xác ở đuôi. Nếu `x`, `y` chỉ 8 bit thì sau 8 vòng **chẳng còn gì** |
| **Hệ số bù `1/K₈`** | `X_INIT = 9949` cần ≥ 14 bit để biểu diễn với độ chính xác hữu ích |
| **Dải giá trị** | `|x|, |y| ≤ K₈ · 9949 ≈ 16384` — cần 15 bit giá trị + 1 bit dấu = **16 bit** |
| **Quy tắc kinh nghiệm CORDIC** | Cần ≈ `N + log₂(N) + 2` bit nội bộ cho `N` bit đầu ra. Với `N = 8`: `8 + 3 + 2 = 13` bit tối thiểu; **16 bit là lựa chọn an toàn** |

⟹ 16 bit **không** phải lãng phí; đó là mức tối thiểu hợp lý. Chi phí: `2 × 16 = 32` FF,
tức gần **một nửa** số FF của khối.

## 4. Đồ thị phụ thuộc trong **một** chu kỳ `S_ITER`

```
  cạnh clock lên
      │
      ├──▶ z_reg[9] ─────────────────────┐   (sẵn sàng ngay — chỉ 1 bit)
      │                                   │
      ├──▶ count[3:0] ──┐  🟥 fanout 42   │
      │                 ▼                 │
      │        ┌────────────────────┐     │
      ├──▶ y_reg│ BỘ DỊCH BIẾN THIÊN│     │   mức 1–3: mux2i + mux4
      │        │  16 bit × 8 vị trí │     │
      │        └─────────┬──────────┘     │
      │                  ▼                ▼
      │        ┌───────────────────────────────┐
      │        │  BỘ CỘNG/TRỪ 16-BIT           │
      │        │  mức 0 : bit 0 (XOR)          │   ← nông nhất
      │        │  …                             │
      │        │  mức 15: carry[15] → bit 15   │   ← sâu nhất
      │        └─────────┬─────────────────────┘
      │                  ▼ x_next / y_next
      │        ┌─────────┴──────────────────────────────┐
      │        │                                        │
      │        ▼ (vòng 1–7)                             ▼ (CHỈ vòng 8)
      │   ┌─────────┐                      ┌────────────────────────────┐
      │   │ x_reg   │                      │  quantize_q14()            │
      │   │ y_reg   │                      │  1. cộng ±64  (bộ cộng nhỏ)│
      │   └─────────┘                      │  2. >>> 7     (0 cell)     │
      │                                    │  3. so >127 / <−128 (BÃO HOÀ)│
      │                                    │  4. đổi dấu theo sign_*     │
      │                                    └───────────┬────────────────┘
      │                                                ▼
      │                                          sin_out / cos_out
      │
      └──▶ count ──▶ ==7 ──▶ state, busy   (đường NGẮN, song song)
```

### Độ sâu logic của từng đích ghi

| Đích | Độ sâu | Ghi chú |
|---|---|---|
| `z_reg[i]` | ≈ `i` tầng carry (10 bit) | Đường ngắn nhất trong ba |
| `x_reg[0]`, `y_reg[0]` | mux dịch + 1 XOR | Nông |
| `x_reg[15]`, `y_reg[15]` | mux dịch + **15 tầng carry** | Sâu — nhưng **không** phải đường tới hạn |
| **`sin_out[7]`, `cos_out[7]`** | mux dịch + 15 tầng carry + **làm tròn + bão hoà + đổi dấu** | 🟥 **Đường tới hạn thật** |
| `count`, `state`, `busy`, `done` | 2–4 cổng | Rất ngắn |

## 5. Dự đoán đường tới hạn — rồi đối chiếu STA thật

**Dự đoán từ RTL:** đường dài nhất **không** phải vòng lặp `x_reg → bộ cộng → x_reg`, mà
là đường **thoát ra** ở vòng cuối: `count → bộ dịch → bộ cộng 16-bit → quantize_q14 →
sin_out`, vì `quantize_q14` được gọi trên `x_next`/`y_next` (**tổ hợp**) chứ không trên
`x_reg`/`y_reg` (đã chốt).

**STA thật (`timing_report_max.txt`, `summary.txt`, `wns.txt`, `tns.txt`):**

| Hạng mục | Giá trị đo | Khớp dự đoán? |
|---|---|:-:|
| Startpoint | `_1655_` = **`count[0]`** | ✅ — và fanout **42**, slew **1,69 ns** |
| Endpoint | `_1603_` = **`sin_out[7]`** | ✅ đúng như dự đoán |
| Data arrival | **11,15 ns** | |
| Data required | 9,84 ns (10,00 − 0,16 setup) | |
| **Slack** | **−1,27 ns — VIOLATED** | 🟥 |
| WNS / TNS | **−1,27 / −13,36** | |
| Số cell | 31 | |
| Trong đó `maj3_1` | **13** liên tiếp | chuỗi carry |

**Phân rã độ trễ đo được:**

| Đoạn | Cell | Cộng dồn | Tỉ lệ |
|---|---|---:|---:|
| `count[0]` clk→Q (fanout 42, slew 1,69 ns) | `dfxtp_1` | **1,45 ns** | 13 % |
| Bộ dịch biến thiên | `mux2i_1`, `o21a_1`, `mux4_2` | 2,44 ns | 9 % |
| **13 tầng carry** | 13 × `maj3_1` ≈ 0,37 ns/tầng | **7,27 ns** | 43 % |
| Hàm SUM | `a21oi_1`, `o21ai_0`, `xor2_1` | ≈ 8,6 ns | |
| **Làm tròn + bão hoà** | `nor3_1`, `nand4_1`, `o31ai_1`, `or4_1`, `o41ai_1`, `o21a_1`… | **11,15 ns** | 35 % |
| **Tổng** | 31 cell | **11,15 ns** | 100 % |

### Ba bài học từ đường tới hạn này

**(1) Một flip-flop đơn lẻ có thể ngốn 13 % ngân sách thời gian.** `count[0]` mất
**1,45 ns** chỉ để clk→Q, với slew **1,69 ns** — vì nó lái **42** đầu vào (hai bộ dịch
biến thiên 16 bit + logic so sánh). Đây là bài học về **fanout**: một thanh ghi điều khiển
lái quá nhiều tải sẽ chậm hơn cả một chuỗi carry ngắn.

**(2) Đường tới hạn ở đây KHÔNG phải vòng lặp.** Nó là đường **thoát ra**, chỉ hoạt động
**một lần** trong 10 chu kỳ. Vậy mà nó quyết định chu kỳ clock của toàn khối. Đây là một
bất cân xứng cổ điển: **1/10 thời gian quyết định 10/10 chi phí.**

**(3) Chữa được mà không tốn chu kỳ nào.** `S_DONE` đã tồn tại và hiện chỉ làm mỗi việc
phát `done`. Chuyển `quantize_q14` sang đó, áp lên `x_reg`/`y_reg` đã chốt, sẽ cắt đoạn
**3,88 ns** khỏi đường tới hạn. Ước tính arrival còn ≈ **7,3 ns** ⟹ slack ≈ **+2,5 ns**.
⚠️ Đây là **ước tính từ phân rã độ trễ**, chưa phải số đo — phải chạy lại STA để xác nhận.
Bản vá chưa áp dụng; xem `tradeoff.md` §7.

## 6. Một chi tiết tinh tế: `sign_cos`/`sign_sin` là tổ hợp, không phải thanh ghi

```systemverilog
always_comb begin
    …
    if (angle < 8'd64) begin  sign_cos = 1'b0;  sign_sin = 1'b0;  end
    …
end
…
cos_out <= sign_cos ? -quantize_q14(x_next) : quantize_q14(x_next);
```

`sign_cos` và `sign_sin` được tính **trực tiếp từ cổng vào `angle`**, không qua thanh ghi.
Chúng được dùng tại `C8` — tức **8 chu kỳ sau** khi `angle` được lấy mẫu.

| Hệ quả | Đánh giá |
|---|---|
| **Tiết kiệm 2 FF** | ✅ nhỏ nhưng thật |
| **Tạo ràng buộc ngầm cho tầng ngoài** | 🟥 `angle` phải giữ **ổn định suốt 9 chu kỳ**, không chỉ tại `C0` |
| Đặc tả có nói điều này không? | ❌ **Không** — `interface.md` chỉ ghi “ổn định khi lấy mẫu”, và `functional_spec.md` §8 ghi “`angle` đổi sau `C0` không ảnh hưởng” **cho `z_init`**, nhưng dấu thì **có** ảnh hưởng |
| Thêm một đường in→reg dài | ⚠️ `angle` → so sánh → `sign_*` → đổi dấu → `sin_out` là đường **input-to-register** cần ràng buộc `set_input_delay` đúng |

> 🟡 **Đây là một lỗi tiềm ẩn chưa gây hại**, vì testbench giữ `angle` cố định suốt giao
> dịch. Trong hệ thống DDS thật, nếu bộ tích luỹ pha cập nhật `angle` giữa chừng, **dấu**
> của kết quả sẽ lấy theo góc mới còn **độ lớn** lấy theo góc cũ ⟹ sai nghiêm trọng.
>
> **Bản vá tối thiểu (chưa áp dụng):** đăng ký `sign_cos`/`sign_sin` tại `C0` cùng lúc với
> `z_reg`:
> ```systemverilog
> logic sign_cos_r, sign_sin_r;
> // trong S_IDLE khi start:
> sign_cos_r <= sign_cos;  sign_sin_r <= sign_sin;
> // tai C8 dung sign_cos_r / sign_sin_r thay vi sign_cos / sign_sin
> ```
> Chi phí: **+2 FF**. Lợi: xoá một ràng buộc ngầm nguy hiểm và rút ngắn một đường in→reg.

## 7. Điều datapath này **chưa** chứng minh

| Chưa chứng minh | Vì sao | Cần gì |
|---|---|---|
| Đạt chu kỳ 10 ns | 🟥 **Đã chứng minh là KHÔNG**: WNS −1,27 ns, TNS −13,36 ns | Chuyển `quantize` sang `S_DONE`, hoặc nới chu kỳ lên ≥ ≈ 11,3 ns |
| Ước tính “slack thành +2,5 ns sau khi sửa” | Suy từ phân rã độ trễ, **không** phải số đo | Sửa rồi chạy lại STA |
| Sai số của **RTL** (khác mô hình chuẩn — `corner_cases.md` §6.2) | Mô phỏng chỉ kiểm 6 góc với dung sai ±4 | Quét đủ 256 góc trên RTL |
| `x_reg`/`y_reg` không tràn (INV-10) | Chưa có assertion | Thêm `assert (x_reg < 16'sd16500)` vào `properties.sv` |
| `sin² + cos² ≈ 128²` (INV-6) | Chưa có assertion | Thêm ca X-5 (`corner_cases.md` §5) |
| Bảng arctan tốn bao nhiêu cell | Bị hoà tan vào MUX, không tách được | Tách thành module riêng rồi tổng hợp — lệnh ở `block_diagram.md` §5 |
| Độ trễ 11,15 ns sau layout | Chưa có ký sinh dây | LibreLane rồi STA lại — **sẽ còn tệ hơn** |

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
