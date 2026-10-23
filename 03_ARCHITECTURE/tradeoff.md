# I05 · Đánh đổi kiến trúc (Trade-off Analysis)

---

## 1. Ba câu hỏi trung tâm của đề

> **Charter mục 2:**
> 1. *“CORDIC đổi phép nhân thành phép dịch và cộng — quyết định kiến trúc đó tiết kiệm
>    bao nhiêu diện tích so với dùng bộ nhân?”*
> 2. *“Tám vòng lặp cho sai số bao nhiêu — lập bảng sai số so với giá trị lý thuyết?”*
> 3. *“Bảng arctan lưu dưới dạng hằng số tốn bao nhiêu cell?”*
>
> **Charter mục 9:** *“Xác nhận không có cell nhân nào, và định lượng sai số so với sin/cos
> thật ở ít nhất 8 góc.”*
>
> **Charter mục 10:** *“Đề khó nhất nhóm I. Sai số là một PHẦN CỦA KẾT QUẢ, không phải
> lỗi — phải lập bảng sai số, không được giấu.”*

## 2. Số liệu thật của I05 và đối chứng trong nhóm I

| Chỉ số | **I05 (CORDIC)** | I04 (Booth) | I03 (dịch–cộng) |
|---|---:|---:|---:|
| Tổng cell | **864** | 258 | 309 |
| Flip-flop | **66** | 49 | 64 |
| Cell tổ hợp | **798** | 209 | 245 |
| Diện tích | **6655,1328 µm²** | 2207,1168 µm² | 2790,176 µm² |
| `maj3_1` (carry) | **40** | 7 | 13 |
| **Cell MUX** (bộ dịch biến thiên) | **77** | **0** | **0** |
| Data arrival | **11,15 ns** | 2,96 ns | 6,41 ns |
| **Slack** | 🟥 **−1,27 ns** | +6,92 ns | +3,47 ns |
| **WNS / TNS** | 🟥 **−1,27 / −13,36** | 0,00 / 0,00 | 0,00 / 0,00 |
| Chu kỳ / kết quả | **10** | 10 | 10 |
| Công suất | **8,10e-04 W** | 2,36e-04 W | 2,93e-04 W |
| — tổ hợp / tuần tự | **59,7 % / 40,3 %** | 11,6 % / 88,4 % | 7,7 % / 92,3 % |
| Ước lượng Charter | ~350–480 cell | ~300–420 | ~250–350 |
| **Đối chiếu** | 🟥 **864 — vượt 80 %** | dưới dải | trong dải |

**Ba điều bất thường của I05 so với hai đề còn lại, và nguyên nhân:**

| Bất thường | Con số | Nguyên nhân |
|---|---|---|
| Cell gấp **2,8×** I03 | 864 vs 309 | **77 cell MUX** (bộ dịch biến thiên) + **ba** bộ cộng chạy song song (16+16+10 bit) thay vì một |
| Công suất tổ hợp **59,7 %** thay vì < 12 % | 8,10e-04 W | **Không có vòng rỗng** — cả ba bộ cộng và cả hai bộ dịch chuyển mạch ở **mọi** vòng |
| Đề **duy nhất** có slack âm | −1,27 ns | `quantize_q14` nằm **trong** vòng lặp (35 % đường tới hạn) + `count[0]` fanout **42** (13 %) |

## 3. Trả lời Charter mục 2 câu 1 — CORDIC so với dùng bộ nhân

> 🟥 **Trả lời trung thực: dữ liệu hiện có KHÔNG chứng minh được CORDIC tiết kiệm diện
> tích — nó gợi ý điều ngược lại.**

| Phương án | Diện tích | Trạng thái bằng chứng |
|---|---:|---|
| **I05 CORDIC, trọn vẹn** | **6655,1328 µm²** | ✅ đo được |
| **Một bộ nhân tuần tự 8×8** (I03, trọn vẹn) | **2790,176 µm²** | ✅ đo được |
| Khối sin/cos dùng đa thức + bộ nhân dùng lại | ⬜ **chưa có** | Cần: 1 bộ nhân + bộ nhớ hệ số + FSM + thanh ghi tích luỹ |
| Bảng tra 256 mục × 2 (`sin`, `cos`) × 8 bit | ⬜ **chưa có** | 4096 bit; không có macro ROM trên Tiny Tapeout ⟹ phải tổng hợp thành logic |

**Nhận xét phải nêu:** `6655 / 2790 ≈ 2,4`. Nghĩa là toàn bộ khối CORDIC **lớn hơn 2,4
lần** một bộ nhân tuần tự trọn vẹn. Câu *“CORDIC tiết kiệm diện tích vì không cần bộ
nhân”* vì vậy **chưa được số liệu ủng hộ** — vì một khối sin/cos dựa trên bộ nhân còn cần
nhiều thứ khác ngoài bộ nhân, nhưng hiệu 3865 µm² là một khoảng đệm rất rộng.

Lý do CORDIC không rẻ như kỳ vọng ở quy mô này: nó **tránh** được bộ nhân nhưng phải trả
bằng **bộ dịch biến thiên** (77 cell MUX) — thứ mà một kiến trúc dùng bộ nhân **không** cần.
Ở độ rộng lớn hơn (16–32 bit) cán cân sẽ nghiêng về CORDIC, vì diện tích bộ nhân tăng theo
`O(N²)` còn bộ dịch chỉ `O(N log N)`.

**⬜ Cách lấy số liệu còn thiếu:**

```bash
# 1. Viet mot khoi sin/cos dung da thuc (vi du xap xi bac 3 tren 1/4 vong tron)
#    tai su dung MOT bo nhan 8x8 tuan tu, cung giao dien start/busy/done
# 2. Tong hop cung dieu kien: Yosys 0.33, sky130_fd_sc_hd, goc tt_025C_1v80
yosys -p "read_verilog -sv poly_sincos.sv; synth -top poly_sincos; \
          dfflibmap -liberty sky130_fd_sc_hd__tt_025C_1v80.lib; \
          abc -liberty sky130_fd_sc_hd__tt_025C_1v80.lib; \
          stat -liberty sky130_fd_sc_hd__tt_025C_1v80.lib"
# 3. So "Chip area" voi 6655,1328 um2 cua I05, VA so ca sai so lan chu ky
# 4. Lam tuong tu cho phuong an bang tra 4096 bit
```

## 4. Trả lời Charter mục 2 câu 2 + mục 9 — **bảng sai số**

### 4.1 Bảng sai số tại 12 góc (≥ 8 góc như Charter đòi)

Đơn vị: **mã Q0.7** (128 = 1,0). Cột “lý thuyết” là `round(128 · sin θ)` / `round(128 · cos θ)`.

| `angle` | Góc (°) | `sin_out` | `cos_out` | `sin` lý thuyết | `cos` lý thuyết | **Δsin** | **Δcos** |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | 0,00 | −1 | 127 | 0 | 127 | **−1** | 0 |
| 21 | 29,53 | 64 | 111 | 63 | 111 | **+1** | 0 |
| 32 | 45,00 | 91 | 90 | 91 | 91 | 0 | **−1** |
| 43 | 60,47 | 113 | 59 | 111 | 63 | **+2** | **−4** |
| 64 | 90,00 | 127 | 3 | 127 | 0 | 0 | **+3** |
| 85 | 119,53 | 113 | −59 | 111 | −63 | **+2** | **+4** |
| 96 | 135,00 | 91 | −90 | 91 | −91 | 0 | **+1** |
| 128 | 180,00 | 1 | −127 | 0 | −128 | **+1** | **+1** |
| 160 | 225,00 | −91 | −90 | −91 | −91 | 0 | **+1** |
| 192 | 270,00 | −127 | −3 | −128 | 0 | **+1** | **−3** |
| 224 | 315,00 | −91 | 90 | −91 | 91 | 0 | **−1** |
| 255 | 358,59 | −5 | 127 | −3 | 127 | **−2** | 0 |

Hai góc `21` và `43` là xấp xỉ gần nhất của **30°** và **60°** mà Charter mục 8 đòi
(hệ brad không biểu diễn chính xác được hai góc này — xem `corner_cases.md` §2).

### 4.2 Thống kê trên **toàn bộ 256 góc**

Từ `error_table()` trong `05_VERIFICATION/golden_model/reference_model.py`:

| |Δ| | 0 | 1 | 2 | 3 | 4 | **5** |
|---|---:|---:|---:|---:|---:|---:|
| Số góc có sai số này ở `sin` | 79 | 85 | 52 | 20 | 16 | **4** |
| Số góc có sai số này ở `cos` | 83 | 91 | 52 | 18 | 12 | 0 |

| Đại lượng | Giá trị | Nguồn |
|---|---:|---|
| **Sai số lớn nhất của `sin`** | **5** mã ≈ **3,9 %** toàn thang | `python_reference_run.log`: `max sine code error: 5` |
| **Sai số lớn nhất của `cos`** | **4** mã ≈ **3,1 %** | `python_reference_run.log`: `max cosine code error: 4` |
| Số góc sai ≤ 1 mã (`sin`) | 164 / 256 = **64 %** | bảng trên |
| Số góc sai ≤ 2 mã (`sin`) | 216 / 256 = **84 %** | bảng trên |

### 4.3 🟡 Cảnh báo về nguồn gốc của bảng

Bảng §4.1 và §4.2 tính từ **mô hình chuẩn Python** (`reference_model.py`), không phải từ
mô phỏng RTL. Hai bên **không bit-exact** — chúng làm tròn khác nhau ở hai trường hợp
(giá trị âm, và giá trị đúng nửa đơn vị); chi tiết ở `corner_cases.md` §6.2. Ở một vài góc
(trong đó có `angle = 0`, `21`, `64`) RTL cho kết quả **lệch 1 mã** so với bảng trên.

⟹ **Bảng sai số của chính RTL: ⬜ chưa đo.** Đây là số liệu cuối cùng còn thiếu để trả lời
trọn vẹn Charter mục 9. Mã testbench để lấy nó nằm ở `corner_cases.md` §6.2.

### 4.4 Phân rã sai số theo nguồn

| Nguồn | Đóng góp ước tính | Giảm được bằng gì |
|---|---|---|
| **E-1** Số vòng hữu hạn (8) | Góc dư ≤ 1 LSB = 1,4° ⟹ ≈ 3 mã | Tăng vòng — **vô ích** nếu không làm E-2 trước |
| **E-2** Bảng arctan làm tròn (`atan[7] = 0`) | ≈ 2–3 mã, **chi phối** | Tăng độ rộng `z` và bảng (Q10.4 thay vì số nguyên) |
| **E-3** Lượng tử hoá Q1.14 → Q0.7 | ≤ 0,5 mã | Tăng độ rộng đầu ra |
| **E-4** Kẹp bão hoà tại +127 | đúng 1 mã tại các cực trị | Không thể — là định nghĩa của Q0.7 |

> 🔎 **Kết luận quan trọng, nhìn thấy trực tiếp trên waveform** (`timing_diagram.md` §2):
> ở `angle = 32`, kết quả sau **vòng 6** (`0,7065 / 0,7075`) **chính xác hơn** kết quả sau
> **vòng 8** (`0,7010 / 0,7131`). Nghĩa là **hai vòng cuối làm kết quả tệ đi**, vì
> `atan[6] = 1` và `atan[7] = 0` không còn mô tả đúng góc quay thật. ⟹ Nguồn sai số chi
> phối là **E-2 (bảng bị làm tròn)**, không phải E-1 (số vòng). Tăng số vòng lên 10, 12 mà
> giữ nguyên bảng sẽ **không** cải thiện gì.

## 5. Trả lời Charter mục 2 câu 3 — bảng arctan tốn bao nhiêu cell

⬜ **Không tách riêng được.** `atan_const()` là một `function` tổ hợp gọi trong
`always_comb`, nên Yosys hoà tan nó vào MUX toán hạng của bộ cộng `z`; trong `netlist.v`
không có ranh giới module hay tên instance tương ứng. Quy trình lấy số (tách thành module
riêng rồi tổng hợp độc lập) ghi đầy đủ ở `block_diagram.md` §5.

**Điều đã biết chắc:** bảng là **8 mục × 10 bit = 80 bit** hằng số, so với **4096 bit** của
phương án bảng tra 256 mục cho cả `sin` và `cos`. Tỉ lệ **1 : 51** về lượng thông tin phải
lưu — và đó chính là lý do đề bài ghi *“không dùng bảng tra lớn”*.

## 6. So bốn kiến trúc tính sin/cos

| Kiến trúc | Chu kỳ | Diện tích | Bộ nhớ hằng | Độ chính xác | Trong phạm vi I05? |
|---|---:|---|---|---|:-:|
| **CORDIC 8 vòng (I05)** | **10** (đo) | **6655,1328 µm²** (đo) | **80 bit** (8 hằng arctan) | ≤ 5 mã / 128 (đo) | ✅ |
| Bảng tra đầy đủ | **1–2** | ⬜ chưa đo | **4096 bit** | Hoàn hảo tới 1 LSB | ❌ Charter mục 1: *“không dùng bảng tra lớn”* |
| Bảng tra 1/4 vòng + đối xứng | **2–3** | ⬜ chưa đo | **1024 bit** | Hoàn hảo tới 1 LSB | ⚠️ vẫn là “bảng tra”, cần hỏi giảng viên |
| Đa thức (Taylor/Chebyshev) + bộ nhân | ≈ 30–40 | ⬜ chưa đo (bộ nhân riêng: 2790 µm²) | ≈ 32–64 bit hệ số | Phụ thuộc bậc | ⚠️ dùng bộ nhân — trái tinh thần đề |
| **CORDIC trải phẳng (unroll 8 tầng)** | **1** (tổ hợp) hoặc 8 (ống) | ước ≈ **8×** phần datapath | 80 bit | như I05 | ❌ đổi kiến trúc |

> ⚠️ **Ràng buộc phạm vi (Charter mục 3):** CORDIC chế độ vector, độ chính xác cao hơn và
> dấu phẩy động đều **ngoài phạm vi**. Bảng trên chỉ để so sánh trên giấy.

## 7. Bốn đánh đổi **nội bộ** mà RTL đã chọn — và giá của chúng

| # | Lựa chọn trong RTL | Giá đã trả | Phương án khác | Đánh giá |
|---|---|---|---|---|
| 🟥 **T-1** | **`quantize_q14` gọi trên `x_next`/`y_next` (tổ hợp), ngay trong `S_ITER`** (dòng 139–144) | **≈ 3,88 ns ≈ 35 %** đường tới hạn ⟹ **nguyên nhân chính của WNS −1,27 ns** | Gọi trên `x_reg`/`y_reg` **đã chốt**, trong `S_DONE` — trạng thái vốn đã tồn tại và **đang rảnh** | **Đánh đổi tệ nhất trong hồ sơ.** Chi phí: **0 chu kỳ, ≈ 0 diện tích**. Lợi: arrival ước còn ≈ 7,3 ns ⟹ slack ≈ **+2,5 ns** |
| **T-2** | **Lặp** thay vì trải phẳng | **77 cell MUX** cho bộ dịch biến thiên + `count[0]` fanout **42** (1,45 ns) | Trải 8 tầng: dịch thành **hằng số** = **0 cell** | Đánh đổi **không hiển nhiên**: ở I03/I04 việc lặp là miễn phí; ở CORDIC nó **phải trả thêm** |
| **T-3** | `x`, `y` rộng **16 bit** Q1.14 | **+32 FF** (gần một nửa số FF) | 12–13 bit là mức tối thiểu lý thuyết | **Đúng** — dưới 13 bit thì sai số lượng tử sẽ lấn át sai số thuật toán |
| **T-4** | `sign_cos`/`sign_sin` **không** đăng ký | Tiết kiệm 2 FF, nhưng tạo **ràng buộc ngầm**: `angle` phải ổn định suốt 9 chu kỳ, và thêm một đường in→reg dài | Đăng ký chúng tại `C0` (**+2 FF**) | **Nên sửa** — 2 FF là giá rẻ để xoá một bẫy nguy hiểm (`control.md` §4, bẫy 2) |

## 8. Những đánh đổi **KHÔNG được phép** trong đề này

| Cấm | Căn cứ | Hậu quả nếu vi phạm |
|---|---|---|
| Dùng **bảng tra** 256 mục cho `sin`/`cos` | Charter mục 1: *“không dùng bảng tra lớn”* | Sai đề; mất toàn bộ nội dung |
| Dùng toán tử `*` ở bất kỳ đâu | Toàn bộ luận điểm của đề là CORDIC **không cần** nhân; Charter mục 9 đòi xác nhận trên báo cáo cell | Sai đề, và `maj3_1` sẽ vọt lên hàng trăm |
| **CORDIC chế độ vector** | Charter mục 3 — ngoài phạm vi | Sai đề |
| **Độ chính xác cao hơn** (16 vòng, Q2.30) | Charter mục 3 — ngoài phạm vi | Sai đề |
| **Dấu phẩy động** | Charter mục 3 — ngoài phạm vi | Sai đề |
| **Giấu bảng sai số** hoặc chỉ nêu góc đẹp | Charter mục 10 nói thẳng | Mất điểm nặng nhất của đề |
| Gọi slack âm là “lỗi công cụ” hay bỏ qua | STA là bằng chứng | Che giấu vi phạm thật |
| Đọc arrival 11,15 ns thành một con số MHz nào đó | Chưa P&R, một góc PVT | Phát biểu vượt mức |
| Tăng số vòng lặp để “giảm sai số” mà không sửa bảng arctan | §4.4: nguồn chi phối là E-2 | Tốn chu kỳ và diện tích mà **không** cải thiện |

## 9. Nếu được phép đổi, nên đổi gì — xếp theo ưu tiên

| Ưu tiên | Đổi gì | Lợi | Rủi ro |
|---|---|---|---|
| **1** | **Chuyển `quantize_q14` sang `S_DONE`**, áp lên `x_reg`/`y_reg` đã chốt | Ước cắt **3,88 ns** khỏi đường tới hạn ⟹ slack từ **−1,27** thành ≈ **+2,5 ns**. **Không** tốn chu kỳ, **không** tốn diện tích đáng kể | **Rất thấp** — chỉ dời vị trí một phép tính |
| 2 | **Đăng ký `sign_cos`/`sign_sin` tại `C0`** | Xoá bẫy “`angle` phải ổn định 9 chu kỳ”; rút ngắn đường in→reg | Thấp — **+2 FF** |
| 3 | Đăng ký thêm bản `count` **one-hot 8 bit** cho bộ dịch | Giảm fanout từ 42 xuống ≈ 5; ước cắt thêm ≈ 0,7–1,0 ns | Thấp — **+8 FF** |
| 4 | Bỏ `busy <= 1'b0;` ở dòng 145 | Xoá bẫy giao diện `busy`/`done` | Rất thấp |
| 5 | Tăng độ rộng `z` và bảng arctan (ví dụ Q10.4) | Giảm nguồn sai số **chi phối** (E-2) | Trung bình — phải tính lại toàn bộ bảng và `X_INIT` |
| 6 | Trải phẳng vòng lặp (unroll) | Bộ dịch thành hằng số (0 cell); có thể chia ống để đạt 1 mẫu/chu kỳ | **Cao** — diện tích ≈ 8× phần datapath; vượt 1×1 tile |

**Không mục nào đã được áp dụng.** Hồ sơ giữ nguyên RTL gốc; mọi thay đổi cần giảng viên
duyệt, và sau khi sửa phải **chạy lại STA và cập nhật mọi con số** trong `06_GDSII/`.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
