# I05 · Giản đồ thời gian (Timing Diagram)

> ❗ **Điều kiện tạo ra giản đồ này.** Dựng lại từ **mã RTL thật** và `simulation.log`, ở
> mức mô phỏng **hành vi (zero-delay)**: tín hiệu đổi **đúng tại** cạnh clock, không có
> `t_ckq`, không glitch. Giản đồ chứng minh **số chu kỳ, thứ tự sự kiện và quỹ đạo hội tụ**;
> nó **không** minh hoạ độ trễ thật.
>
> 🟥 Với I05 điều này đặc biệt quan trọng: khối **PASS** ở mức hành vi nhưng **KHÔNG ĐẠT**
> ràng buộc thời gian (WNS `−1,27 ns`). Giản đồ chu kỳ đẹp **không** bảo đảm mạch chạy
> được — xem §6.

---

## 1. Quy ước đánh số chu kỳ

| Ký hiệu | Định nghĩa |
|---|---|
| `C0` | Cạnh clock lên có `state == S_IDLE` và `start == 1` → nạp `x=9949, y=0, z=z_init` |
| `C1 … C8` | Tám cạnh trong `S_ITER`; tại `Ck` thực hiện vòng lặp CORDIC thứ `k` với `count = k−1` |
| `C9` | Cạnh trong `S_DONE` → `done` lên |
| `C10` | Về `S_IDLE`, `done` xuống |

Giá trị trong bảng là giá trị **đang giữ** trong khoảng `[Ck, Ck+1)`.

## 2. Giản đồ dạng sóng cho một phép tính đầy đủ: `angle = 32` (45°)

Chọn ca này vì nó nằm trong testbench (dòng 60), và vì `sin 45° = cos 45°` nên quỹ đạo hội
tụ nhìn rất rõ: `x` và `y` phải gặp nhau.

`z_init = 32` (vì `32 < 64`), `sign_cos = 0`, `sign_sin = 0`.

```
 chu kỳ:      reset   C0    C1    C2    C3    C4    C5    C6    C7    C8    C9    C10
 thời gian:           25ns  35    45    55    65    75    85    95   105   115   125
                │      │     │     │     │     │     │     │     │     │     │     │
        ┌──┐  ┌─┴┐   ┌─┴┐  ┌─┴┐  ┌─┴┐  ┌─┴┐  ┌─┴┐  ┌─┴┐  ┌─┴┐  ┌─┴┐  ┌─┴┐  ┌─┴┐  ┌─┴┐
 clk  ──┘  └──┘  └───┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──
              ┌───────────────────────────────────────────────────────────────────────
 rst_n ───────┘   (lên tại t=15 ns — reset ĐỒNG BỘ)
                 ┌────┐
 start ──────────┘    └──────────────────────────────────────────────────────────────
 angle   xx   │ 32  │ 32  │ 32  │ 32  │ 32  │ 32  │ 32  │ 32  │ 32  │ 32  │ 32  │ 32
              │     │  🟥 PHẢI giữ ổn định TỚI C8 (sign_cos/sign_sin là tổ hợp!)

 count   xxxx │  0  │  1  │  2  │  3  │  4  │  5  │  6  │  7  │  7  │  7  │  7
 lượng dịch───┼─ >>0┼─ >>1┼─ >>2┼─ >>3┼─ >>4┼─ >>5┼─ >>6┼─ >>7┼──────┼─────┼─────
 atan[count]──┼─ 32 ┼─ 19 ┼─ 10 ┼─  5 ┼─  3 ┼─  1 ┼─  1 ┼─  0 ┼──────┼─────┼─────
              │     │     │     │     │     │     │     │     │     │     │
 z_reg[9] ────┼──0──┼──0──┼──1──┼──1──┼──1──┼──1──┼──0──┼──1──┼──1──┼─────┼─────
 chiều quay───┼─ +  ┼─ +  ┼─ −  ┼─ −  ┼─ −  ┼─ −  ┼─ +  ┼─ −  ┼─────┼─────┼─────
              │     │     │     │     │     │     │     │     │     │     │
 z_reg   xxxx │  32 │   0 │ −19 │  −9 │  −4 │  −1 │   0 │  −1 │  −1 │  −1 │  −1
              │     │     │     │     │     │     │     │     │  ▲ z dao động quanh 0
              │     │     │     │     │     │     │     │     │    (atan[7]=0 nên C8 không sửa z)
              │     │     │     │     │     │     │     │     │     │     │
 x_reg   xxxx │ 9949│ 9949│ 4975│ 8705│10415│11202│11575│11394│11485│11485│11485
 x/2^14       │.6072│.6072│.3036│.5313│.6357│.6837│.7065│.6954│.7010│     │
              │     │     │     │     │     │     │     │     │  ▲ hội tụ về 0,7071
              │     │     │     │     │     │     │     │     │     │     │
 y_reg   xxxx │    0│ 9949│14923│13680│12592│11942│11592│11772│11683│11683│11683
 y/2^14       │.0000│.6072│.9108│.8350│.7686│.7289│.7075│.7185│.7131│     │
              │     │     │     │     │     │     │     │     │  ▲ hội tụ về 0,7071
              │     │     │     │     │     │     │     │     │     │     │
 state   xxxx │IDLE │ITER │ITER │ITER │ITER │ITER │ITER │ITER │ITER │DONE │IDLE │IDLE
              │     ┌─────────────────────────────────────────────┐             │
 busy  ───────┼─────┘        8 chu kỳ: [C0, C8)                   └─────────────┼───
              │     │     │     │     │     │     │     │     │     │     ┌─────┐
 done  ───────┼─────┼─────┼─────┼─────┼─────┼─────┼─────┼─────┼─────┼─────┘     └───
              │     │     │     │     │     │     │     │     │     │  1 chu kỳ │
 cos_out  cũ  │ cũ  │ cũ  │ cũ  │ cũ  │ cũ  │ cũ  │ cũ  │ cũ  │ cũ  │  90 │  90 │  90
 sin_out  cũ  │ cũ  │ cũ  │ cũ  │ cũ  │ cũ  │ cũ  │ cũ  │ cũ  │ cũ  │  91 │  91 │  91
              │     │     │     │     │     │     │     │     │     │  ▲ hợp lệ TỪ C8
              │     │     │     │     │     │     │     │     │     │   (sớm hơn done 1 chu kỳ)
```

### Đọc giản đồ — năm điều phải thấy

**1. Vòng đầu tiên quay tới **45°**, rồi các vòng sau quay ngược lại dần.** `atan[0] = 32`
= đúng 45°. Vì `z_init = 32`, sau vòng 1 thì `z = 0` — đã “tới nơi”. Nhưng CORDIC
**không dừng được**: nó buộc phải chạy đủ 8 vòng, và các vòng sau sẽ quay qua quay lại
quanh đích. Đó là lý do `z` chạy `32 → 0 → −19 → −9 → −4 → −1 → 0 → −1 → −1`.

**2. `x` và `y` hội tụ về nhau, đúng như `sin 45° = cos 45°`.**

| Sau vòng | `x/2^14` | `y/2^14` | Chênh |
|---|---:|---:|---:|
| 1 | 0,6072 | 0,6072 | 0,0000 |
| 2 | 0,3036 | 0,9108 | 0,6072 |
| 4 | 0,6357 | 0,7686 | 0,1329 |
| 6 | 0,7065 | 0,7075 | 0,0010 |
| **8** | **0,7010** | **0,7131** | 0,0121 |
| Lý thuyết | 0,7071 | 0,7071 | 0 |

Chú ý: sau **vòng 6** kết quả (`0,7065 / 0,7075`) đã **tốt hơn** sau vòng 8
(`0,7010 / 0,7131`). Đây **không** phải nghịch lý — nó là hệ quả trực tiếp của việc bảng
arctan bị làm tròn: `atan[6] = 1` và `atan[7] = 0` không còn mô tả đúng góc quay thật của
hai vòng cuối, nên hai vòng đó **quay quá tay**. Đây là nguồn sai số **E-2** trong
`functional_spec.md` §7.1, và nó nhìn thấy được ngay trên waveform.

**3. `atan[7] = 0` ⟹ vòng 8 không hiệu chỉnh góc nữa.** `z` giữ `−1` qua `C8`. Vòng 8 chỉ
còn làm một việc: quay `x`, `y` thêm `2^−7`. Nó vẫn có ích cho biên độ, nhưng với góc thì
**vô tác dụng**. ⟹ Muốn chính xác hơn thì **không** thể chỉ tăng số vòng; phải **tăng độ
rộng của `z` và của bảng arctan** trước.

**4. Lượng dịch đổi ở **mọi** chu kỳ** (`>>0, >>1, …, >>7`). Đây là chỗ khác biệt lớn nhất
so với I03/I04, nơi lượng dịch luôn là 1. Chính vì lượng dịch **biến thiên** mà I05 cần
**77 cell mux** cho hai bộ dịch — và đó là nguồn 864 cell.

**5. `angle` phải giữ ổn định tới `C8`, không chỉ tại `C0`.** `sign_cos`/`sign_sin` là tổ
hợp thuần từ `angle` và được đọc ở `C8`. Đây là một ràng buộc ngầm chưa được ghi trong
`interface.md` — xem `control.md` §4, bẫy 2.

## 3. Ca đối chiếu: `angle = 0` — vì sao `sin` **không** đúng bằng 0

```
 vòng:         C1    C2    C3    C4    C5    C6    C7    C8
 atan:         32    19    10     5     3     1     1     0
 chiều:         +     −     −     −     +     −     +     −
 z_reg:       −32   −13    −3     2    −1     0    −1    −1
 x_reg:      9949 14923 16166 16321 16370 16377 16382 16381   → /2^14 = 0,9998
 y_reg:      9949  4975  1245  −775   245  −266   −11  −138   → /2^14 = −0,0084
 kết quả:    cos_out = 127 (kẹp bão hoà)  ·  sin_out = −2
 lý thuyết:  cos = 127                    ·  sin = 0
```

`sin_out = −2` thay vì `0`: sai **2 mã trên 128 ≈ 1,6 %**. Đây là **hành vi đúng của
CORDIC 8 vòng**, không phải lỗi. Testbench chấp nhận vì dung sai là `±4` (dòng 40).

Quan sát thêm: `y` dao động `+9949 → +4975 → +1245 → −775 → +245 → −266 → −11 → −138`.
Nó **đang** hội tụ về 0 (tại vòng 7 chỉ còn `−11`!) nhưng vòng 8 lại đẩy nó ra `−138`. Đây
lại là hệ quả của `atan[7] = 0` — vòng 8 quay mà không có góc để quay.

## 4. Số chu kỳ cần cho một kết quả

| Đại lượng | Số chu kỳ | Giải thích |
|---|---:|---|
| Nạp (`C0`) | 1 | `S_IDLE` → `S_ITER`, nạp `X_INIT` và `z_init` |
| Vòng lặp (`C1`…`C8`) | **8** | Một chu kỳ cho mỗi vòng CORDIC |
| Báo xong (`C9`) | 1 | `S_DONE` |
| **Từ `start` tới `done`** | **9** | |
| **Từ `start` tới `sin_out`/`cos_out` hợp lệ** | **8** | |
| **Một mẫu, chạy liên tiếp** | **10** | |
| Thông lượng | **1 mẫu / 10 chu kỳ** | |

**Số chu kỳ KHÔNG phụ thuộc `angle`** (INV-7): góc 0° và góc 359° đều tốn đúng 10 chu kỳ.
Đây là tính chất quan trọng cho ứng dụng DDS — tần số ra ổn định, không jitter do dữ liệu.

### Bằng chứng từ log mô phỏng thật

`05_VERIFICATION/simulation.log`:

```
I05 RTL TB PASS
…/i05_cordic_core_tb.sv:64: $finish called at 615 (1s)
```

| Bước suy luận | Căn cứ |
|---|---|
| Chu kỳ clock = 10 ns | `always #5 clk = ~clk;` (dòng 19) |
| `rst_n` lên tại `t = 15 ns` | `repeat(2) @(posedge clk); rst_n = 1;` (dòng 53–54) |
| `C0` của ca 1 ở `t = 25 ns` | `run_case` đặt `start` tại `@(negedge clk)` = `t = 20 ns` |
| Testbench chạy **6** ca | dòng 56–61 |
| `615 = t(done ca 1) + 5·T` | `$finish` ngay sau ca 6 |
| Với mô hình 9 / 10 chu kỳ: `t(done ca 1) = 25 + 90 = 115`, `T = 100 ns` | §4 |
| Kiểm: `115 + 5 × 100 = 615` | ✅ **khớp đúng con số trong log** |

> ℹ️ Đề anh em I04 dùng đúng khung testbench này; log của nó in thẳng `Time: 115` cho ca
> đầu tiên — xác nhận mốc `t(done ca 1) = 115 ns` bằng quan sát trực tiếp.

## 5. Sai số theo góc — không phụ thuộc thời gian, nhưng phải nêu

| `angle` | Góc | Sai số điển hình | Nguồn chính |
|---:|---|---|---|
| 0 | 0° | `sin` sai ≈ 2 mã | Vòng 8 “quay quá tay” (`atan[7] = 0`) |
| 32 | 45° | `cos` sai ≈ 1 mã | Lượng tử hoá Q1.14 → Q0.7 |
| 64 | 90° | `cos` sai vài mã | `x_next` gần 0, sai số tương đối lớn |
| 128 | 180° | `cos` = −127 thay vì −128 | Kẹp bão hoà |

Bảng sai số đầy đủ (đo trên mô hình chuẩn, và ghi rõ chỗ RTL lệch với mô hình chuẩn):
`tradeoff.md` §4 và `corner_cases.md` §6.

## 6. 🟥 Nối giản đồ chu kỳ với độ trễ thật — và chỗ KHÔNG đạt

```
  ├──────────── T_clk = 10 ns (GIẢ ĐỊNH của design.sdc) ──────────────┤
  ▲ cạnh Ck                                                  ▲ Ck+1
  ├── 1,45 ns ──┤
  │ count[0] clk→Q (FANOUT 42, slew 1,69 ns)
  │             ├─ 0,99 ns ─┤
  │             │ bộ dịch biến thiên (mux2i, mux4_2)
  │                         ├──── 4,83 ns: 13 tầng carry (maj3_1) ────┤
  │                                                                   ├── 3,88 ns ──┐
  │                                                                   │ quantize:   │
  │                                                                   │ làm tròn +  │
  │                                                                   │ BÃO HOÀ     │
  ├──────────────────── 11,15 ns: data arrival ──────────────────────────────────────┤
  │                                                                   │             │
  ├──────── 9,84 ns: data required ────────────────────────┤          │             │
                                                            🟥 SLACK = −1,27 ns
```

| Nguồn | Con số |
|---|---:|
| `sta/timing_report_max.txt` — startpoint → endpoint | `_1655_` (`count[0]`) → `_1603_` (`sin_out[7]`) |
| Data arrival | **11,15 ns** |
| Data required (10,00 − 0,16 setup) | 9,84 ns |
| `sta/summary.txt` — slack | **−1,27 ns — VIOLATED** |
| `wns.txt` / `tns.txt` | **`wns max -1.27`** / **`tns max -13.36`** |
| Số cell trên đường | 31 |

**Ba kết luận bắt buộc phải nêu:**

1. **Chu kỳ 10 ns là KHÔNG đủ.** Cần ít nhất `11,15 + 0,16 ≈ 11,3 ns` (≈ 88 MHz) ngay cả
   **trước** khi có ký sinh dây. Sau layout con số sẽ còn lớn hơn.
2. **TNS `−13,36 ns` cho biết đây không phải một đường lẻ.** Danh sách trong
   `timing_report_max.txt` cho thấy **hàng chục** đường vi phạm, tất cả đều bắt đầu từ
   `count[0]` và kết thúc ở các bit của `sin_out`/`cos_out`. Đây là vi phạm **có hệ thống**
   của một cấu trúc, không phải một lỗi ngẫu nhiên.
3. **Có cách chữa không tốn chu kỳ.** Chuyển `quantize_q14` sang `S_DONE` (trạng thái đã
   tồn tại và đang rảnh) cắt được đoạn **3,88 ns** khỏi đường tới hạn ⟹ arrival ước còn
   ≈ 7,3 ns, slack ≈ **+2,5 ns**. ⚠️ Đây là **ước tính từ phân rã độ trễ**, chưa phải số
   đo. Xem `tradeoff.md` §7. **Chưa áp dụng.**

## 7. Điều giản đồ này **chưa** chứng minh

| Chưa chứng minh | Vì sao | Cần gì |
|---|---|---|
| Mạch chạy được ở 10 ns | 🟥 **Đã chứng minh là KHÔNG** (WNS −1,27 ns) | Sửa kiến trúc hoặc nới chu kỳ |
| Ước tính “slack thành +2,5 ns sau khi chuyển `quantize`” | Suy từ phân rã độ trễ | Sửa rồi chạy lại STA |
| Waveform thật trùng giản đồ | Chưa có file VCD trong hồ sơ | Thêm `$dumpfile`/`$dumpvars`, chạy lại, chụp artifact có chú thích |
| Quỹ đạo `x`, `y`, `z` của **RTL** đúng như bảng §2 | Bảng dựng từ mô hình hoá lại RTL; testbench chỉ kiểm **kết quả cuối**, không kiểm từng vòng | Thêm `$display` trong `S_ITER` hoặc dump VCD |
| Sai số của RTL trên đủ 256 góc | Mô phỏng chỉ kiểm 6 góc với dung sai ±4 | Quét 256 góc — mã ở `corner_cases.md` §6.2 |
| Bẫy “`angle` đổi giữa chừng” gây lỗi | Testbench giữ `angle` cố định | Thêm ca đổi `angle` ở `C4` và quan sát dấu |
| Không có glitch | Zero-delay không sinh glitch | Mô phỏng SDF (L5 — `CHUA CHAY`) |

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
