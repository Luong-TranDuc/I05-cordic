# I05 — Bộ tính sin và cos bằng CORDIC 8-bit · Ghi chú thực hiện

> 🟡 **Tóm tắt trạng thái:** khối **đúng chức năng** (`I05 RTL TB PASS`) nhưng **không đạt
> ràng buộc thời gian giả định** (WNS **−1,27 ns**, TNS **−13,36 ns**) và **vượt 80 %** quy
> mô cell mà Charter dự đoán (864 so với 350–480). Đây là đề duy nhất trong nhóm I có slack
> âm — và nguyên nhân đã được truy ra tới **một dòng mã** (§2, §8).

## 1. Bài toán này thực chất là gì

Charter mục 1 nêu: *“Khối tính sin/cos để tạo dạng sóng trong bộ phát tín hiệu thử, không
dùng bảng tra lớn.”* Vế sau mới là đề bài thật.

Tính `sin` và `cos` cho 256 góc rời rạc là chuyện **tầm thường** nếu được dùng bảng tra:
hai mảng 256 × 8 bit là xong, sai số bằng 0, độ trễ một chu kỳ. Nhưng 4096 bit hằng số
trên một ô Tiny Tapeout — nơi **không có macro ROM** — phải trở thành logic tổ hợp, và nó
sẽ rất đắt.

Vậy đề này hỏi: **có cách nào tính lượng giác mà chỉ cần 80 bit hằng số không?** CORDIC trả
lời: có — nếu chấp nhận **8 chu kỳ** và **sai số tới ≈ 4 %**. Ba con số `80 bit / 8 chu kỳ /
4 %` là toàn bộ nội dung của đề, và Charter mục 10 nhấn mạnh rằng con số thứ ba **phải
được đo và công bố**, không được giấu.

Điều làm đề này khó nhất nhóm I không phải thuật toán, mà là ở chỗ: kết quả **luôn sai**,
nên không thể dùng phép so bằng để kiểm — phải lập bảng sai số, phải giải thích sai số đến
từ đâu, và phải biết sai số nào là **cố hữu** còn sai số nào là **sửa được**.

## 2. Bản chất kỹ thuật — cơ chế hoạt động

CORDIC dựa trên một quan sát: phép **quay** vector

```
   x' = x·cos φ − y·sin φ
   y' = y·cos φ + x·sin φ
```

nếu chọn `φ` sao cho `tan φ = 2^(−i)`, có thể viết lại thành

```
   x' = cos φ · (x − y·2^(−i))
   y' = cos φ · (y + x·2^(−i))
```

Nhân với `2^(−i)` là **phép dịch**. Còn hệ số `cos φ` thì **không phụ thuộc chiều quay**,
nên nó tích luỹ thành một hằng số `K₈ ≈ 1,6467` sau 8 vòng và được **bù trước** bằng cách
khởi tạo `x = round(2^14 / K₈) = 9949`. Đó là trọn vẹn cơ chế: **bỏ phép nhân, giữ lại phép
dịch và phép cộng**, còn hệ số khuếch đại thì trả một lần ở đầu.

Mỗi vòng ta chọn quay **cùng chiều** hay **ngược chiều** tuỳ theo góc dư `z` còn dương hay
âm — đây là một tìm kiếm nhị phân trên góc. Sau 8 vòng, `z → 0` và vector đã quay đúng góc
cần.

Nhưng có **hai nút thắt**, và cả hai đều không nằm ở chỗ người ta thường nghĩ.

**Nút thắt thứ nhất — sai số không đến từ “chỉ có 8 vòng”, mà từ bảng arctan bị làm tròn.**
Bảng trong RTL là `[32, 19, 10, 5, 3, 1, 1, 0]`. Hai mục cuối là `1` và `0`, trong khi giá
trị thật là `0,64` và `0,32`. Nghĩa là hai vòng cuối quay **sai lượng**, và vòng thứ 8
không hiệu chỉnh góc chút nào (`atan[7] = 0`). Bằng chứng nhìn thấy trực tiếp trên
waveform: ở `angle = 32`, kết quả sau **vòng 6** (`x/2^14 = 0,7065`, `y/2^14 = 0,7075`)
**chính xác hơn** kết quả sau **vòng 8** (`0,7010 / 0,7131`). **Hai vòng cuối làm kết quả
tệ đi.** Hệ quả thực hành: tăng số vòng lên 10 hay 12 mà giữ nguyên bảng sẽ **không** cải
thiện gì — phải tăng độ rộng của `z` và của bảng trước.

**Nút thắt thứ hai — đường tới hạn không nằm trong vòng lặp.** Nó nằm ở đường **thoát ra**:
`count → bộ dịch biến thiên → bộ cộng 16-bit → quantize_q14 → sin_out`, và đoạn
`quantize_q14` (làm tròn + **bão hoà**) chiếm **35 %** của 11,15 ns. Đoạn này chỉ chạy
**một lần trong 10 chu kỳ**, nhưng nó quyết định chu kỳ clock của **toàn bộ** thiết kế.
Thêm nữa, `count[0]` có fanout **42** (nó lái hai bộ dịch biến thiên 16 bit), slew
**1,69 ns**, độ trễ clk→Q **1,45 ns** — **13 %** ngân sách, chỉ từ một flip-flop.

## 3. Đọc mã nguồn: RTL làm gì, từng dòng quan trọng

Trái tim thuật toán, dòng 92–100:

```systemverilog
if (z_reg >= 0) begin
    x_next = x_reg - (y_reg >>> count);
    y_next = y_reg + (x_reg >>> count);
    z_next = z_reg - atan_const(count[2:0]);
end else begin
    x_next = x_reg + (y_reg >>> count);
    y_next = y_reg - (x_reg >>> count);
    z_next = z_reg + atan_const(count[2:0]);
end
```

**Ba điểm phải thấy:**

1. **Cả hai dòng đều đọc `x_reg`, không đọc `x_next`.** Nếu viết nhầm
   `y_next = y_reg + (x_next >>> count)` thì thuật toán sai **và** hai bộ cộng bị nối tiếp
   — đường tới hạn gấp đôi. RTL làm đúng.
2. **`>>> count` là bộ dịch BIẾN THIÊN.** Ở I03/I04 lượng dịch luôn là 1 nên tốn **0 cell**;
   ở đây nó là 77 cell MUX. Đây là điểm đánh đổi **không hiển nhiên** của việc lặp trong
   CORDIC.
3. **`z_reg >= 0` chỉ là bit dấu `z_reg[9]`** — một tín hiệu điều khiển gần như miễn phí,
   nhưng nó lái cả 42 bit dữ liệu.

Khâu gây slack âm, dòng 136–146:

```systemverilog
if (count == 4'd7) begin
    cos_out <= sign_cos ? -quantize_q14(x_next) : quantize_q14(x_next);
    sin_out <= sign_sin ? -quantize_q14(y_next) : quantize_q14(y_next);
```

`x_next` và `y_next` là **tín hiệu tổ hợp** — chúng vừa ra khỏi bộ cộng 16-bit trong **cùng
chu kỳ**. Áp thêm `quantize_q14` (một phép cộng nhỏ, một phép dịch, **hai phép so sánh bão
hoà**) và một phép đổi dấu lên chúng nghĩa là nối thêm ≈ 3,88 ns vào một đường vốn đã dài
7,27 ns. Bản chú thích ngay trên đó nói rõ ý định — *“sign restoration and output
quantization use the post-iteration values”* — nhưng đó chính là lựa chọn phải trả giá.

Hàm lượng tử hoá, dòng 52–58:

```systemverilog
if (v >= 0) scaled = v + 32'sd64;
else        scaled = v - 32'sd64;
q = scaled >>> 7;
```

Ý đồ là “làm tròn về số gần nhất”: cộng nửa đơn vị rồi cắt. Nhưng `>>>` là **dịch số học**
= `floor`, chứ không phải cắt-về-0. Với `v < 0`, `floor((v−64)/128)` **lệch một mã xuống**
so với làm tròn đúng. Ví dụ `v = −138` (chính là `y` cuối cùng của `angle = 0`): RTL cho
`−2`, làm tròn đúng cho `−1`. Đây là nguyên nhân khiến RTL và mô hình chuẩn **không
bit-exact** ở 16/256 góc (`corner_cases.md` §6.2) — dung sai `±4` của testbench che mất nó.

Cuối cùng, dòng 74–90 (gập góc) sinh `sign_cos`/`sign_sin` **tổ hợp thuần từ `angle`**,
nhưng chúng lại được dùng ở `C8` — **8 chu kỳ sau**. Ràng buộc ngầm: `angle` phải ổn định
suốt 9 chu kỳ, không chỉ tại `C0`. Không có tài liệu nào trong hồ sơ nói điều này trước khi
`control.md` §4 chỉ ra.

## 4. Vì sao chọn kiến trúc này

| Tiêu chí của ứng dụng | CORDIC lặp đáp ứng? |
|---|---|
| **Không dùng bảng tra lớn** | ✅ 80 bit hằng so với 4096 bit — tỉ lệ **1 : 51** |
| Không cần phép nhân | ✅ Xác nhận trên netlist: **0** cell nhân, **0** macro bộ nhớ |
| Độ trễ cố định, không phụ thuộc dữ liệu | ✅ 10 chu kỳ cho mọi góc ⟹ DDS không bị jitter |
| Diện tích nhỏ | ⚠️ **864 cell, vượt 80 %** dự đoán; lớn hơn **2,4 lần** một bộ nhân tuần tự trọn vẹn |
| Đạt chu kỳ 10 ns | 🟥 **Không** — WNS −1,27 ns |
| Sai số chấp nhận được | ⚠️ tới **5 mã / 128 ≈ 3,9 %** — phải công bố, không giấu |

Cần nói thẳng: **hai trong sáu tiêu chí không đạt.** Điều đó không làm kiến trúc sai — nó
làm **hiện thực** cần sửa. Cả hai chỗ không đạt đều truy được về nguyên nhân cụ thể và cả
hai đều có hướng sửa chi phí thấp (§8, §10).

## 5. Cách thực hiện — lộ trình 8 bước từ đặc tả tới GDSII

| Bước | Việc | Đầu ra | Trạng thái |
|---|---|---|---|
| 1 | Chốt định dạng số (Q1.14 nội bộ, Q0.7 ra) và tính `X_INIT`, bảng arctan **trước** khi viết RTL | `functional_spec.md` §2–§3 | ✅ |
| 2 | Mô hình chuẩn Python; kiểm `X_INIT == 9949`, `ATAN == [32,19,10,5,3,1,1,0]` | `test_constants` | ✅ **PASS** |
| 3 | **Lập bảng sai số trên mô hình chuẩn trước khi viết RTL** — để biết mức sai số nào là cố hữu | `error_table()`, `test_error_bounds` | ✅ max 5 / 4 |
| 4 | Viết RTL, cấm `*` và cấm bảng tra | `i05_cordic_core.sv` | ✅ |
| 5 | Testbench với **dung sai** (không so bằng) | `simulation.log`: `I05 RTL TB PASS` | ✅ 6 góc, ±4 |
| 6 | **Quét đủ 256 góc trên RTL và so từng bit với mô hình chuẩn** | bảng sai số của RTL | ⬜ **chưa làm** |
| 7 | Tổng hợp + STA, **đọc đường tới hạn theo tên net** | 864 cell · WNS −1,27 ns | ✅ chạy · 🟥 không đạt |
| 8 | Sửa kiến trúc theo §10, chạy lại, rồi P&R | | ⬜ chưa làm |

Bước 3 là điểm đáng học của quy trình này: **lập bảng sai số trên mô hình chuẩn TRƯỚC**,
để khi RTL cho kết quả lệch vài mã thì ta biết đó là sai số **thuật toán** (chấp nhận được)
hay sai số **hiện thực** (phải sửa).

## 6. Số liệu thật đã đo được và cách đọc chúng

| Chỉ số | Giá trị | Chứng minh gì | **Không** chứng minh gì |
|---|---:|---|---|
| `I05 RTL TB PASS` | `simulation.log` | Đúng ở **6 góc** với dung sai ±4 | **Không** nói gì về 250 góc còn lại |
| `max sine error: 5`, `max cosine error: 4` | `python_reference_run.log` | Sai số của **mô hình chuẩn** trên đủ 256 góc | **Không** phải sai số của RTL — hai bên lệch ở 16/256 góc |
| **864 cell** | `synth_stat.txt` | **Vượt 80 %** dải Charter (350–480) ⟹ có thể cần 2×1 tile | |
| **66 FF** | `synth_stat.txt` | Khớp chính xác `32 + 10 + 16 + 4 + 2 + 2`; hơn **gấp đôi** dự đoán 27–30 | |
| **77 cell MUX** | bảng phân bố cell | Bộ dịch **biến thiên** — chi phí riêng của việc **lặp** CORDIC | |
| **40 `maj3_1`** | bảng phân bố cell | **Ba** bộ cộng (16+16+10 bit); và số này đủ nhỏ để khẳng định **không có mảng nhân** | |
| **0 cell nhân, 0 macro bộ nhớ** | `physical_report.md` §2, `synth_stat.txt` | ✅ **Xác nhận Charter mục 9** | |
| **arrival 11,15 ns, slack −1,27 ns** | `timing_report_max.txt` | 🟥 **KHÔNG đạt** chu kỳ 10 ns giả định | **Không** phải số sau layout — sẽ còn tệ hơn |
| **TNS −13,36 ns** | `tns.txt` | Vi phạm **có hệ thống** (hàng chục đường), không phải một đường lẻ | |
| **8,10e-04 W, tổ hợp 59,7 %** | `power_report.txt` | Đề **duy nhất** có tổ hợp lấn át — vì CORDIC **không có vòng rỗng** | **Ước lượng** mặc định, **không** từ VCD |
| `$finish at 615` | `simulation.log` | 9 chu kỳ tới `done`, 10 chu kỳ/mẫu | |

## 7. Trả lời các câu hỏi kỹ thuật của Charter (mục 2)

**Câu 1 — “CORDIC tiết kiệm bao nhiêu diện tích so với dùng bộ nhân?”**

Trả lời trung thực: **dữ liệu hiện có không ủng hộ khẳng định đó.** I05 trọn vẹn là
**6655,1328 µm²**; một bộ nhân tuần tự 8×8 trọn vẹn (I03) là **2790,176 µm²** — tức I05
lớn hơn **2,4 lần**. CORDIC **tránh** được bộ nhân nhưng phải trả bằng **77 cell MUX** của
bộ dịch biến thiên, thứ mà kiến trúc dùng bộ nhân không cần. Ở `N = 8` cán cân chưa nghiêng
về CORDIC; nó sẽ nghiêng khi `N` lớn hơn, vì diện tích bộ nhân tăng `O(N²)` còn bộ dịch chỉ
`O(N log N)`. ⬜ Để kết luận dứt khoát cần tổng hợp một khối sin/cos dựa trên đa thức + bộ
nhân, cùng thư viện và cùng script — lệnh ở `tradeoff.md` §3.

**Câu 2 — “Tám vòng lặp cho sai số bao nhiêu — lập bảng sai số?”**

Bảng 12 góc và thống kê trên đủ 256 góc: `tradeoff.md` §4. Tóm tắt: **max |Δsin| = 5**,
**max |Δcos| = 4** (đơn vị: mã trên thang 128, tức ≈ 3,9 % và 3,1 %); **64 %** số góc sai
≤ 1 mã, **84 %** sai ≤ 2 mã. Nguồn chi phối **không** phải số vòng mà là **bảng arctan bị
làm tròn** (`atan[6] = 1`, `atan[7] = 0`) — bằng chứng: ở `angle = 32`, kết quả sau vòng 6
chính xác hơn sau vòng 8. ⚠️ Bảng này đo trên **mô hình chuẩn**; bảng của **RTL** ⬜ chưa đo.

**Câu 3 — “Bảng arctan lưu dưới dạng hằng số tốn bao nhiêu cell?”**

⬜ **Không tách riêng được** — `atan_const()` là `function` gọi trong `always_comb`, bị
Yosys hoà tan vào MUX toán hạng của bộ cộng `z`; netlist không có ranh giới tương ứng.
Quy trình lấy số (tách thành module riêng, tổng hợp độc lập cùng thư viện): `block_diagram.md`
§5. Điều đã biết chắc: bảng là **80 bit** hằng so với **4096 bit** của bảng tra đầy đủ.

## 8. Trả lời câu phân tích riêng (Charter mục 9)

> *“Xác nhận không có cell nhân nào trong báo cáo sử dụng cell, và định lượng sai số so với
> sin/cos thật ở ít nhất 8 góc.”*

**Phần 1 — không có cell nhân:** ✅ **XÁC NHẬN.** Rà đủ 55 loại cell trong
`06_GDSII/physical_report.md` §2: chỉ có cổng logic cơ bản, cổng phức hợp AOI/OAI, XOR/XNOR
(hàm SUM), `maj3_1` ×40 (hàm carry), MUX ×77 (bộ dịch), `dfxtp_1` ×66 (thanh ghi), và cell
đệm/cách ly. **Không có** cell nhân, **không có** DSP/MAC, và `synth_stat.txt` ghi
`Number of memories: 0`.

Bổ sung cho chặt chẽ: thư viện `sky130_fd_sc_hd` vốn **không có** cell nhân nào cả. Vì vậy
lập luận mạnh hơn phải là: *nếu RTL có viết `*`, Yosys sẽ tổng hợp ra một **mảng nhân bằng
standard cell**, và số `maj3_1` sẽ vọt lên hàng trăm.* Con số **40 `maj3_1`** — vừa đủ cho
ba bộ cộng 16 + 16 + 10 bit — là bằng chứng rằng điều đó **không** xảy ra.

**Phần 2 — bảng sai số ở ≥ 8 góc:** bảng 12 góc ở `tradeoff.md` §4.1, trong đó có 4 góc
phần tư, 45°/135°/225°/315°, và hai góc xấp xỉ 30°/60° (`angle = 21` và `43`, vì hệ brad
không biểu diễn chính xác hai góc này). Sai số lớn nhất trong bảng: `Δcos = ±4` tại
`angle = 43` và `85`.

⚠️ **Hai sắc thái bắt buộc phải nêu khi báo cáo:**

1. Bảng được tính trên **mô hình chuẩn Python**, không phải trên RTL. Hai bên **không
   bit-exact**: RTL dùng `>>>` (floor) với giá trị âm và làm tròn lên ở giá trị nửa đơn vị,
   mô hình chuẩn dùng `round()` của Python. Chênh lệch **1 mã ở 16/256 góc** — nhỏ hơn dung
   sai `±4` của testbench nên mô phỏng vẫn PASS. Bảng sai số của **chính RTL** ⬜ **chưa đo**;
   mã testbench để lấy nó ở `corner_cases.md` §6.2.
2. Charter mục 8 đòi **30°** và **60°**, nhưng hệ brad (256 phần/vòng) không biểu diễn được
   hai góc đó (`21,33` và `42,67`). Đã thay bằng `angle = 21` và `43` và ghi rõ lệch này.

## 9. Những chỗ sinh viên hay sai và cách phát hiện

| # | Sai lầm | Hậu quả | Phát hiện bằng bằng chứng nào |
|---|---|---|---|
| 1 | Dùng `x_next` thay `x_reg` khi tính `y_next` | Thuật toán sai **và** hai bộ cộng nối tiếp ⟹ đường tới hạn gấp đôi | Bảng sai số bung ra; STA cho chuỗi carry ≈ 26 tầng thay vì 13 |
| 2 | Quên bù hệ số `1/K₈` (khởi tạo `x = 2^14` thay vì `9949`) | Mọi kết quả **lớn hơn 1,65 lần** ⟹ bão hoà hết về `127` | Ca `45°` cho `127/127` thay vì `91/90`; INV-6 (`sin²+cos² ≈ 128²`) vi phạm nặng |
| 3 | Dùng `>>` thay `>>>` cho `x_reg`, `y_reg` | Mất dấu ⟹ sai ở mọi góc phần tư có toạ độ âm | Góc 90°–270° sai hoàn toàn |
| 4 | Quên gập góc, đưa thẳng `angle` vào `z` | CORDIC **không hội tụ** ngoài `|z| ≲ 99,9°` | Góc > 100° cho kết quả vô nghĩa |
| 5 | **Tăng số vòng lặp để giảm sai số** mà giữ nguyên bảng arctan | Tốn chu kỳ và diện tích, sai số **không** giảm | `tradeoff.md` §4.4: ở `angle = 32`, vòng 6 chính xác hơn vòng 8 |
| 6 | Dùng `round()` kiểu “cộng nửa rồi `>>>`” cho **số âm** | Lệch 1 mã xuống ở mọi giá trị âm | `angle = 0`: `y = −138` ⟹ RTL cho `−2`, làm tròn đúng cho `−1` |
| 7 | **Giấu bảng sai số** hoặc chỉ báo cáo góc đẹp | Mất điểm nặng nhất của đề | Charter mục 10 nói thẳng |
| 8 | Dùng so bằng (`===`) trong testbench thay vì dung sai | Testbench FAIL ở mọi góc dù thiết kế đúng | Bản chất CORDIC là xấp xỉ |
| 9 | **Bỏ qua slack âm** vì “mô phỏng đã PASS” | Mạch chạy sai trên silicon ở 100 MHz | `wns.txt`: `wns max -1.27`; `tns.txt`: `tns max -13.36` |
| 10 | Không nhận ra `quantize` nằm trong vòng lặp | Bỏ lỡ cách sửa rẻ nhất (0 chu kỳ, ≈ 0 diện tích) | Đọc đường tới hạn: 11 cell cuối đều là logic so sánh/bão hoà |
| 11 | Coi `count` chỉ là bộ đếm | Bỏ qua fanout **42** — 13 % đường tới hạn từ **một** flip-flop | `timing_report_max.txt` dòng 12: `42  0.18  1.69  1.45` |
| 12 | Đổi `angle` giữa chừng trong hệ thống DDS | Độ lớn theo góc cũ, **dấu** theo góc mới | `control.md` §4, bẫy 2 |

## 10. Câu hỏi mentor nên đặt khi bảo vệ

| # | Câu hỏi | Đáp án mong đợi |
|---|---|---|
| 1 | Mô phỏng PASS nhưng STA FAIL — nghĩa là sao? | Mô phỏng hành vi là **zero-delay**, hoàn toàn mù về thời gian. Mạch **đúng** nhưng **chậm**: cần chu kỳ ≥ ≈ 11,3 ns, không phải 10 ns |
| 2 | Đường tới hạn đi qua đâu, phân rã thế nào? | `count[0]` (fanout 42) **1,45 ns** → bộ dịch biến thiên **0,99 ns** → 13 tầng carry **4,83 ns** → `quantize_q14` (làm tròn + bão hoà) **3,88 ns** → `sin_out[7]`. Tổng **11,15 ns** |
| 3 | Vì sao một flip-flop lại ngốn 1,45 ns? | `count[0]` lái **42** đầu vào (hai bộ dịch biến thiên 16 bit + so sánh); slew **1,69 ns**. `dfxtp_1` là cell nhỏ nhất thư viện |
| 4 | Cách sửa rẻ nhất để có slack dương? | Chuyển `quantize_q14` sang `S_DONE` (trạng thái đã tồn tại và đang rảnh), áp lên `x_reg`/`y_reg` **đã chốt**. Ước cắt 3,88 ns, **không** tốn chu kỳ, **không** tốn diện tích đáng kể |
| 5 | Sai số 8 vòng là bao nhiêu, và **nguồn chi phối** là gì? | max **5** mã (`sin`) / **4** mã (`cos`) trên thang 128. Nguồn chi phối là **bảng arctan bị làm tròn** (`atan[7] = 0`), **không** phải số vòng. Bằng chứng: ở `angle = 32`, vòng 6 chính xác hơn vòng 8 |
| 6 | Tăng số vòng lên 12 thì sai số giảm bao nhiêu? | **Gần như không giảm** — `atan[7]` đã bằng 0, các mục sau cũng sẽ bằng 0. Phải tăng độ rộng `z` và bảng trước |
| 7 | Chứng minh không có cell nhân nào? | Rà đủ 55 loại cell trong `physical_report.md` §2: 0 cell nhân, 0 DSP, `Number of memories: 0`. Lập luận mạnh: nếu có `*`, `maj3_1` sẽ vọt lên hàng trăm thay vì **40** |
| 8 | `X_INIT = 9949` là gì và vì sao? | `round(2^14 / K₈)` với `K₈ = ∏sqrt(1+2^(−2i)) ≈ 1,6467`. Bù trước hệ số khuếch đại của 8 vòng quay. Mô hình chuẩn tính độc lập và ra **đúng 9949** |
| 9 | Vì sao `x`, `y` cần 16 bit khi đầu ra chỉ 8 bit? | Mỗi vòng mất bit thấp do dịch phải; quy tắc `N + log₂N + 2` cho `N=8` ra ≈ 13 bit tối thiểu. 16 bit là lựa chọn an toàn; giá là **+32 FF** |
| 10 | Vì sao I05 có 864 cell trong khi I03 chỉ 309? | **77 cell MUX** cho hai bộ dịch **biến thiên** (I03/I04 dịch hằng số = 0 cell) + **ba** bộ cộng song song thay vì một |
| 11 | Vì sao công suất tổ hợp của I05 là 59,7 % trong khi I03 chỉ 7,7 %? | CORDIC **không có vòng rỗng**: cả ba bộ cộng và cả hai bộ dịch chuyển mạch ở **mọi** vòng. I03 có vòng “giữ nguyên”, I04 có tới 7/8 vòng `NOP` |
| 12 | CORDIC có thật sự tiết kiệm diện tích so với bộ nhân không? | Với số liệu hiện có thì **chưa chứng minh được**: I05 = 6655 µm², bộ nhân tuần tự trọn vẹn (I03) = 2790 µm². CORDIC thắng ở chỗ **không cần bảng tra** (80 bit so với 4096 bit) và ở độ rộng bit lớn hơn |
| 13 | RTL và mô hình chuẩn có bit-exact không? | **Không** — lệch 1 mã ở 16/256 góc, do quy tắc làm tròn khác nhau ở giá trị âm và ở giá trị nửa đơn vị. Dung sai ±4 của testbench che mất |

## 11. Giới hạn: đã chứng minh được gì, chưa chứng minh được gì

**Đã chứng minh:**

- Thuật toán CORDIC 8 vòng cho `sin`/`cos` đúng trong giới hạn sai số đã công bố: max
  **5** mã (`sin`), **4** mã (`cos`) trên thang 128 — đo trên mô hình chuẩn, đủ 256 góc.
- RTL đúng ở **6 góc** với dung sai ±4 (`I05 RTL TB PASS`).
- ✅ **Không có cell nhân nào** (Charter mục 9) — rà đủ 55 loại cell, `Number of memories: 0`.
- Bảng hằng arctan chỉ **80 bit**, so với **4096 bit** của bảng tra đầy đủ — tỉ lệ 1 : 51.
- Số chu kỳ: **9 tới `done`, 10 cho một mẫu**, **không** phụ thuộc góc.
- 🟥 **Thiết kế KHÔNG đạt chu kỳ 10 ns**: WNS −1,27 ns, TNS −13,36 ns, arrival 11,15 ns.
- Nguyên nhân slack âm được truy tới từng đoạn: `quantize_q14` trong vòng lặp (35 %),
  chuỗi carry (43 %), `count[0]` fanout 42 (13 %), bộ dịch biến thiên (9 %).
- Nguồn sai số chi phối là **bảng arctan bị làm tròn**, không phải số vòng lặp.
- RTL và mô hình chuẩn **không bit-exact** (lệch 1 mã ở 16/256 góc) — đã truy ra nguyên
  nhân ở hai quy tắc làm tròn khác nhau.

**Chưa chứng minh:**

- ⬜ **Bảng sai số của chính RTL** trên đủ 256 góc (Charter mục 9 đòi) — mới có bảng của
  mô hình chuẩn.
- ⬜ Ước tính “chuyển `quantize` sang `S_DONE` cho slack ≈ +2,5 ns” — suy từ phân rã độ
  trễ, chưa chạy lại STA.
- ⬜ Chi phí cell của **riêng** bảng arctan (Charter mục 2 câu 3).
- ⬜ So sánh diện tích với khối sin/cos dựa trên bộ nhân, và với phương án bảng tra
  (Charter mục 2 câu 1).
- ⬜ Waveform có chú thích (Charter mục 3, thành phần 5) — chưa bật `$dumpvars`.
- ⬜ Công suất theo hoạt động thật (VCD) — số hiện tại là ước lượng mặc định.
- ⬜ Mô phỏng gate-level (L4) và post-layout SDF (L5) — `test_matrix.csv` ghi `CHUA CHAY`.
- ⬜ STA sau routing — sẽ **tệ hơn** 11,15 ns vì thêm ký sinh dây.
- ⬜ Nhánh `default` của FSM (`2'b11`) — chưa có ca kiểm.
- ⬜ Bẫy “`angle` đổi giữa chừng” — chưa có ca kiểm.
- ⬜ Lớp vỏ chân Tiny Tapeout mà Charter mục 4 yêu cầu — RTL không có `ui_in`/`uio_*`.
- ⬛ CORDIC chế độ vector, độ chính xác cao hơn, dấu phẩy động, tape-out — Charter mục 3
  ghi **ngoài phạm vi**.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
