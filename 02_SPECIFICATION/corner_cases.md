# I05 · Ca biên và ca góc (Corner Cases)

---

## 1. Bốn trục phủ của một khối CORDIC

```
   Trục 1 — GÓC PHẦN TƯ  : bốn nhánh gập (0–63, 64–127, 128–191, 192–255)
   Trục 2 — BIÊN ĐỘ      : chỗ sin/cos chạm ±1,0 → khâu kẹp bão hoà
   Trục 3 — SAI SỐ       : góc nào sai nhiều nhất, và sai bao nhiêu
   Trục 4 — THỜI GIAN    : số chu kỳ, busy/done
```

Trục 3 là trục **riêng của đề này**. Với I03/I04, kết quả chỉ có *đúng* hoặc *sai*. Với
I05, kết quả **luôn sai một chút** — và nội dung của bài là **đo và giải thích** cái sai đó.
Charter mục 10 nói thẳng: *“Sai số là một PHẦN CỦA KẾT QUẢ, không phải lỗi — phải lập bảng
sai số, không được giấu.”*

## 2. Ca bắt buộc của Charter mục 8 — và một lệch cần ghi nhận

| # | Ca Charter | Mã góc tương ứng | Lý do kỹ thuật | Trong TB? |
|---|---|---|---|:-:|
| M-1 | **Góc 0** | `angle = 0` | `z_init = 0`. Vòng 1 vẫn quay `+45°` rồi các vòng sau quay ngược — kiểm rằng thuật toán **hội tụ trở lại** chứ không đứng yên | ✅ dòng 56 |
| M-2 | **30°** | `21,33` — **không nguyên** | Góc này **không** rơi đúng vào một mã brad | 🟥 **KHÔNG CÓ** |
| M-3 | **45°** | `angle = 32` | Góc đối xứng: `sin = cos`. Bất kỳ lỗi bất đối xứng giữa hai nhánh `x`/`y` sẽ lộ ngay | ✅ dòng 60 |
| M-4 | **60°** | `42,67` — **không nguyên** | Như M-2 | 🟥 **KHÔNG CÓ** |
| M-5 | **90°** | `angle = 64` | Biên giữa góc phần tư I và II; ép `sign_cos = 1` và `x_next ≈ 0` (có thể **hơi âm**) | ✅ dòng 57 |
| M-6 | **Lập bảng sai số** so với lý thuyết | — | Yêu cầu trung tâm | ⚠️ **gián tiếp** — xem §6 |

> 🟡 **Lệch so với Charter phải ghi nhận:** hệ góc của khối là **brad** (256 phần/vòng),
> nên 30° và 60° không biểu diễn chính xác được (`21,33` và `42,67`). Testbench thay bằng
> 4 góc phần tư + 45° + 315°. Đây là lựa chọn **hợp lý** nhưng **phải nói ra**, và nên bổ
> sung `angle = 21` (≈ 29,53°) và `angle = 43` (≈ 60,47°) làm ca xấp xỉ — xem §5 (X-1).

## 3. Ca đã có thật trong testbench

Đọc `i05_cordic_core_tb.sv` dòng 56–61; dung sai `±4` mã (dòng 40, 44):

| Dòng | `angle` | Góc | `sin` kỳ vọng | `cos` kỳ vọng | Trục được phủ |
|---:|---:|---|---:|---:|---|
| 56 | 0 | 0° | 0 | 127 | 1 (phần tư I), 2 (`cos` chạm `+1`) |
| 57 | 64 | 90° | 127 | 0 | 1 (biên I/II), 2 (`sin` chạm `+1`) |
| 58 | 128 | 180° | 0 | −128 | 1 (biên II/III), 2 (`cos` chạm `−1`) |
| 59 | 192 | 270° | −128 | 0 | 1 (biên III/IV), 2 (`sin` chạm `−1`) |
| 60 | 32 | 45° | 91 | 91 | 1, **đối xứng** `sin = cos` |
| 61 | 224 | 315° | −91 | 91 | 1 (phần tư IV), đối xứng |

Kết quả: `simulation.log` ghi `I05 RTL TB PASS`, `$finish called at 615`.

> ⚠️ **Hạn chế của bộ ca này:** cả 6 góc đều là **bội số của 32** (trừ không có góc nào
> khác). Chúng phủ tốt trục 1 và 2 nhưng **bỏ trống trục 3** — không góc nào trong số này
> là góc có sai số lớn nhất. Xem §5 và §6.

## 4. Phân loại riêng của đề — theo **nhánh gập góc**

| Nhánh (dòng RTL) | Dải `angle` | `z_init` | `sign_cos` | `sign_sin` | Ca đại diện | Đã phủ? |
|---|---|---|:-:|:-:|---|:-:|
| 74–77 | `0 … 63` | `angle` | `+` | `+` | 0, 32 | ✅ |
| 78–81 | `64 … 127` | `128 − angle` | `−` | `+` | 64 | ✅ (chỉ ở **biên dưới**) |
| 82–85 | `128 … 191` | `angle − 128` | `−` | `−` | 128 | ✅ (chỉ ở **biên dưới**) |
| 86–90 | `192 … 255` | `256 − angle` | `+` | `−` | 192, 224 | ✅ |

**Lỗ hổng phủ:** nhánh 2 và nhánh 3 chỉ được kiểm ở **đúng một điểm**, và điểm đó lại là
**biên dưới** của nhánh (`64` và `128`) — nơi `z_init` bằng `64` hoặc `0`, hai giá trị đặc
biệt. Không có ca nào ở **giữa** nhánh 2 hay nhánh 3. Nếu ai đó viết nhầm `128 - angle`
thành `angle - 128`, ca `angle = 64` vẫn cho `z_init = 64` đúng (vì `|64−128| = 64`), nên
lỗi **không lộ ra**. Xem ca X-2.

## 5. Ca tự xây dựng bổ sung (yêu cầu: ít nhất 2, có ca biên)

| ID | Ca | Loại | Lý do kỹ thuật |
|---|---|---|---|
| **X-1** | `angle = 21` (≈ 29,53°) và `angle = 43` (≈ 60,47°) | Charter | Xấp xỉ gần nhất của **30°** và **60°** mà Charter mục 8 đòi. Cũng là góc **không** phải bội của 32 ⟹ dùng nhiều mục của bảng arctan hơn |
| **X-2** | `angle = 96` (135°) và `angle = 160` (225°) | phủ nhánh | **Giữa** nhánh 2 và nhánh 3 — hai nhánh hiện chỉ được kiểm ở biên dưới. Ca này bắt được lỗi hoán vị `128 − angle` ↔ `angle − 128` |
| **X-3** | `angle = 63, 65, 127, 129, 191, 193, 255` | **biên** | Các mã **ngay sát** ranh giới nhánh gập. Đây là nơi lỗi `<` / `<=` sẽ lộ ra. Mô hình chuẩn đã có `test_quadrant_boundaries` cho đúng danh sách này; RTL thì ⬜ chưa |
| **X-4** | Quét **toàn bộ 256 góc**, lập bảng sai số | **Charter mục 9** | Đây là ca Charter đòi đích danh. Mô hình chuẩn có `error_table()`; RTL ⬜ chưa. Xem §6 |
| **X-5** | Kiểm `sin_out² + cos_out² ≈ 128²` cho mọi góc | bất biến | INV-6. Bắt được lỗi ở **hệ số bù `X_INIT`** mà bảng sai số theo từng góc có thể bỏ sót |
| **X-6** | Hai giao dịch liên tiếp: `angle = 32` rồi `angle = 0` | thời gian | Kiểm `x_reg`, `y_reg`, `z_reg` được nạp lại sạch ở `S_IDLE`. Nếu quên `y_reg <= '0'`, ca này sẽ lệch rõ |
| **X-7** | `start` phát lại đúng tại `C9` | thời gian | Ép bẫy giao diện `busy` xuống sớm hơn `done` (`control.md` §4) |
| **X-8** | So **từng bit** đầu ra RTL với mô hình chuẩn trên đủ 256 góc | đối chiếu | Phát hiện chỗ RTL và mô hình chuẩn **không bit-exact** — xem §6.2. Testbench hiện dùng dung sai `±4`, **che mất** khác biệt 1 mã |

## 6. Bảng sai số — trạng thái thật và chỗ cần cẩn thận

### 6.1 Số liệu **đã đo được**

`05_VERIFICATION/python_reference_run.log`:

```
I05 golden reference PASS
max sine code error: 5
max cosine code error: 4
```

Đây là sai số lớn nhất trên **toàn bộ 256 góc**, của **mô hình chuẩn Python**, so với
`round(128·sin θ)` / `round(128·cos θ)`. Bảng chi tiết theo góc: `tradeoff.md` §4.

### 6.2 ⚠️ Mô hình chuẩn và RTL **không** bit-exact — phát hiện quan trọng

Hai bên hiện thực **cùng thuật toán** nhưng **khác quy tắc làm tròn** ở khâu lượng tử hoá
cuối:

```systemverilog
// RTL, dòng 53–58
if (v >= 0) scaled = v + 32'sd64;
else        scaled = v - 32'sd64;
q = scaled >>> 7;                    // >>> là DỊCH SỐ HỌC = làm tròn XUỐNG (floor)
```

```python
# Mô hình chuẩn, dòng 20–22
q = int(round(v / S * 128.0))        # round() của Python = làm tròn về SỐ CHẴN gần nhất
```

Hai khác biệt cụ thể:

| # | Trường hợp | RTL | Mô hình chuẩn | Ví dụ |
|---|---|---|---|---|
| **D-1** | `v < 0` | `floor((v−64)/128)` — cách viết `−64` chỉ đúng khi dùng **cắt về 0**, nhưng `>>>` là **floor** ⟹ **lệch 1 mã xuống** | `round(v/128)` | `angle = 0`: `y = −138` ⟹ RTL cho `−2`, mô hình chuẩn cho `−1` |
| **D-2** | `v/128` đúng bằng **nửa đơn vị** | làm tròn **lên** (`+64` rồi floor) | làm tròn về **số chẵn** | `angle = 21`: `y = 8256`, `8256/128 = 64,5` ⟹ RTL cho `65`, mô hình chuẩn cho `64` |

Cả hai đều **lệch đúng 1 mã**, và đều **nhỏ hơn dung sai `±4`** của testbench — nên mô
phỏng vẫn `PASS`. Nhưng hệ quả là:

> 🟡 **Không được dùng con số “max sine error = 5, max cosine error = 4” như thể đó là sai
> số của RTL.** Nó là sai số của **mô hình chuẩn**. Sai số thật của RTL ⬜ **chưa đo**, và
> theo phân tích D-1 (lệch xuống ở giá trị âm) nó **có thể lớn hơn ở một vài góc**.

**⬜ Cách lấy bảng sai số thật của RTL:**

```systemverilog
// Them vao testbench — KHONG dung vao RTL
initial begin
    integer p, es, ec;
    $display("angle, sin_out, cos_out, sin_ly_thuyet, cos_ly_thuyet, err_sin, err_cos");
    for (p = 0; p < 256; p = p + 1) begin
        @(negedge clk); angle = p[7:0]; start = 1'b1;
        @(negedge clk); start = 1'b0;
        wait(done);
        es = $signed(sin_out) - $rtoi($floor(128.0*$sin(2*3.14159265358979*p/256)+0.5));
        ec = $signed(cos_out) - $rtoi($floor(128.0*$cos(2*3.14159265358979*p/256)+0.5));
        $display("%0d,%0d,%0d,%0d,%0d", p, $signed(sin_out), $signed(cos_out), es, ec);
    end
end
```

Xuất ra CSV, so cột `err_*` với bảng của mô hình chuẩn, và **liệt kê riêng những góc lệch**.
Đó mới là bảng sai số mà Charter mục 9 đòi.

## 7. Ca **KHÔNG** áp dụng cho đề này — và vì sao

| Ca | Vì sao không áp dụng |
|---|---|
| Tràn `x_reg`/`y_reg` | INV-10: `K₈ · 9949 ≈ 16384 < 32767`. Với 8 vòng và `X_INIT = 9949` thì không tràn. ⚠️ Nhưng **sẽ** tràn nếu ai đó tăng số vòng mà không đổi `X_INIT` |
| **CORDIC chế độ vector** (tính `atan2`, độ lớn) | Charter mục 3 — **ngoài phạm vi** |
| **Độ chính xác cao hơn** (16 vòng, Q2.30) | Charter mục 3 — ngoài phạm vi |
| **Dấu phẩy động** | Charter mục 3 — ngoài phạm vi |
| Góc > 360° hoặc âm | Không tồn tại: `angle` là 8 bit không dấu, đã tự quy về một vòng |
| Chia cho 0 | Không có phép chia |
| Glitch / hazard | Mô phỏng zero-delay không sinh glitch — chỉ thấy ở mức SDF (L5, `CHUA CHAY`) |
| CDC | Một clock duy nhất |
| Reset bất đồng bộ giữa hai cạnh clock | `rst_n` là reset **đồng bộ** |

## 8. Ca phải bổ sung khi chuyển sang gate-level / post-layout

| Lớp | Ca mới cần có | Bắt lỗi gì |
|---|---|---|
| **Ưu tiên cao nhất** | **Ca timing**: kiểm lại đường `count → bộ dịch → bộ cộng → quantize → sin_out` | I05 là đề **duy nhất có slack âm** (WNS **−1,27 ns**, TNS **−13,36 ns**). Ở mức RTL zero-delay, vi phạm này **hoàn toàn vô hình** |
| L4 — gate-level | Chạy lại đủ 256 góc trên `netlist.v` | Sai lệch tổng hợp; và **quan trọng hơn**: netlist là nơi kiểm được là không có cell nhân nào (Charter mục 9) |
| L4 | `force state = 2'b11` rồi kiểm phục hồi | Nhánh `default` có sống sót qua tổng hợp không |
| **L5 — SDF** | Góc bất kỳ, góc `ss`, **chu kỳ 10 ns** | **Sẽ FAIL** — đã có WNS âm ngay từ sau tổng hợp. Ca này dùng để **xác nhận** vi phạm, không phải để hy vọng nó biến mất |
| L5 | Quét chu kỳ clock: 10, 11, 12, 13 ns | Tìm chu kỳ nhỏ nhất mà thiết kế **thật sự** đạt. Từ arrival 11,15 ns ⟹ cần **≥ ≈ 11,3 ns** ngay cả khi chưa có ký sinh dây |
| L5 | Ca `count` chuyển 7→0 (fanout 42) | `count[0]` có fanout **42** với slew **1,69 ns** — đây là nút thắt; sau layout nó còn tệ hơn |

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
