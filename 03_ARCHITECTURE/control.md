# I05 · Phần điều khiển (Control)

I05 là mạch **tuần tự**. Tài liệu này mô tả khối điều khiển thật, đọc từ
`04_IMPLEMENTATION/rtl/i05_cordic_core.sv`.

---

## 1. Phần điều khiển gồm những gì

| Thành phần | Khai báo | FF | Vai trò |
|---|---|---:|---|
| Thanh ghi trạng thái | `state_t state;` (dòng 32) | 2 | Chọn pha nạp / lặp / xong |
| **Bộ đếm vòng** | `logic [3:0] count;` (dòng 21) | 4 | Đếm 0…7 — **và điều khiển bộ dịch biến thiên** |
| Cờ bận | `busy` | 1 | Báo tầng ngoài |
| Cờ xong | `done` | 1 | Xung một chu kỳ |
| **Tổng** | | **8 / 66 FF** | **12,1 %** |

Ngoài ra có **hai** khối điều khiển tổ hợp, đều không thuộc FSM:

| Thành phần | Khai báo | FF | Vai trò |
|---|---|---:|---|
| **Chọn chiều quay** | `if (z_reg >= 0)` (dòng 92, 96) | 0 | Quyết định `+`/`−` cho cả ba bộ cộng — lấy lệnh từ **dữ liệu** (`z_reg[9]`) |
| **Gập góc** | `if (angle < …)` (dòng 74–90) | 0 | Sinh `z_init`, `sign_cos`, `sign_sin` — lấy lệnh từ **cổng vào** |

## 2. `count` — thanh ghi điều khiển tốn kém nhất hồ sơ

`count` trong I03 và I04 chỉ làm một việc: đếm tới 7. Trong I05 nó làm **ba** việc:

| Vai trò của `count` | Tải |
|---|---|
| Đếm vòng (0…7) | Logic tăng 4 bit — rẻ |
| So sánh `== 4'd7` để kết thúc | Vài cổng — rẻ |
| 🟥 **Chọn lượng dịch** cho `x_reg >>> count` và `y_reg >>> count` | **2 bộ dịch biến thiên 16 bit** |
| 🟥 **Chọn mục bảng arctan** `atan_const(count[2:0])` | MUX 8→1 trên 10 bit |

Hệ quả đo được trong `sta/timing_report_max.txt`:

```
     42    0.18    1.69    1.45    1.45 ^ _1655_/Q (sky130_fd_sc_hd__dfxtp_1)
     ▲      ▲       ▲       ▲
  fanout   cap    slew    delay              net: count[0]
```

| Đại lượng | Giá trị | Nhận xét |
|---|---:|---|
| Fanout của `count[0]` | **42** | Lớn nhất trong toàn thiết kế |
| Điện dung tải | 0,18 pF | |
| Slew | **1,69 ns** | Rất chậm — sườn tín hiệu bị kéo dài |
| Độ trễ clk→Q | **1,45 ns** | **13 %** toàn bộ đường tới hạn 11,15 ns |

> 🔎 **Bài học:** `dfxtp_1` là cell nhỏ nhất của thư viện. Đặt nó lái 42 tải mà không cho
> tool cơ hội nhân bản (`clone`) hay đệm là cách chắc chắn nhất để tạo nút thắt. Ở đây
> `abc` đã chèn 14 `lpflow_isobufsrc_1` + 13 `lpflow_inputiso1p_1` nhưng vẫn không cứu
> được, vì bản thân cell nguồn quá yếu.
>
> **Hướng chữa (chưa áp dụng):** đăng ký thêm một bản `count` dạng **one-hot 8 bit** dành
> riêng cho bộ dịch. Chi phí +8 FF, lợi: mỗi bit one-hot chỉ lái ≈ 4–6 tải, và bộ dịch
> biến thành mạng AND-OR một mức thay vì cây mux nhiều mức.

## 3. Bảng tín hiệu điều khiển của FSM

| Tín hiệu | Sinh ở đâu | Tác dụng lên datapath | Dòng |
|---|---|---|---|
| `state == S_IDLE && start` | FSM + cổng vào | **Nạp**: `x_reg ← X_INIT (9949)`, `y_reg ← 0`, `z_reg ← z_init`, `count ← 0` | 120–127 |
| `state == S_ITER` | FSM | **Cập nhật** `x_reg ← x_next`, `y_reg ← y_next`, `z_reg ← z_next` — **vô điều kiện** | 131–134 |
| `z_reg >= 0` | **datapath** | Chọn chiều quay `d = ±1` cho cả ba bộ cộng | 92, 96 |
| `count[2:0]` | bộ đếm | Chọn mục bảng arctan **và** lượng dịch | 93–99 |
| `count == 4'd7` | bộ đếm | **Chốt kết quả**: `cos_out ← …`, `sin_out ← …`, `busy ← 0`, `state ← S_DONE` | 136–146 |
| `count != 4'd7` | bộ đếm | `count ← count + 1` | 147–149 |
| `sign_cos`, `sign_sin` | **tổ hợp từ `angle`** | Đổi dấu đầu ra tại `C8` | 139–144 |
| `state == S_DONE` | FSM | `done ← 1`, `state ← S_IDLE` | 152–156 |
| `!rst_n` | cổng vào | **Xoá đồng bộ** | 104–113 |

**Đặc điểm:** dòng 131–134 nằm **ngoài** mọi điều kiện dữ liệu — CORDIC **luôn** quay ở
mọi vòng, chỉ **chiều** quay là thay đổi. Đây là khác biệt với I03/I04, nơi có vòng “không
làm gì”. Ở CORDIC **không có vòng rỗng**, nên mọi vòng đều tiêu năng lượng như nhau — và
đây là một phần lý do công suất tổ hợp của I05 chiếm **59,7 %** (so với 7,7 % ở I03).

## 4. Bắt tay với tầng ngoài — và **hai** bẫy

| Tín hiệu | Hướng | Quy tắc |
|---|---|---|
| `start` | vào | Chỉ tác dụng khi `state == S_IDLE` |
| `angle` | vào | 🟥 Phải giữ **ổn định suốt 9 chu kỳ** — xem bẫy 2 |
| `busy` | ra | Cao trên `[C0, C8)` |
| `done` | ra | Cao trên `[C9, C10)` — đúng 1 chu kỳ |

> ⚠️ **BẪY 1 — `busy` xuống trước `done` một chu kỳ** (giống I03, I04). Trên `[C8, C9)`:
> `busy == 0`, `done == 0`, nhưng `state == S_DONE`. Master viết `if (!busy) start <= 1;`
> sẽ phát lệnh ở `C9` và lệnh đó **biến mất không báo lỗi**. Nguyên nhân: `busy <= 1'b0;`
> ở dòng 145 (tại `C8`) còn `state <= S_IDLE` ở dòng 155 (tại `C9`).
>
> **Bản vá:** bỏ `busy <= 1'b0;` ở dòng 145, để `S_DONE` tự hạ. **Chưa áp dụng.**

> 🟥 **BẪY 2 — `angle` phải giữ ổn định cả 9 chu kỳ, KHÔNG chỉ tại `C0`.** `sign_cos` và
> `sign_sin` là **tổ hợp thuần** từ `angle` (dòng 74–90) và được dùng tại `C8`
> (dòng 139–144), tức **8 chu kỳ sau** khi `z_init` đã chốt. Nếu tầng ngoài đổi `angle`
> giữa chừng:
>
> ```
>    z_init  lấy theo angle CŨ  (đã chốt vào z_reg tại C0)   → ĐỘ LỚN đúng theo góc cũ
>    sign_*  lấy theo angle MỚI (tổ hợp, đọc tại C8)          → DẤU sai
>    ⟹ kết quả có độ lớn của góc này nhưng dấu của góc kia
> ```
>
> Đây là một ràng buộc ngầm **không được ghi** ở `interface.md`. Trong kiến trúc DDS
> (`system_diagram.md` §1), bộ tích luỹ pha cập nhật `angle` theo nhịp riêng — nguy cơ
> thật. **Bản vá:** đăng ký `sign_cos`/`sign_sin` tại `C0` (+2 FF). Xem `datapath.md` §6.
> **Chưa áp dụng.**

## 5. Reset đồng bộ

```systemverilog
always_ff @(posedge clk) begin
    if (!rst_n) begin        // ← KHÔNG có "or negedge rst_n"
```

| Hệ quả | Chi tiết |
|---|---|
| `rst_n` chỉ tác dụng tại cạnh clock lên | Clock đứng yên ⟹ reset vô hiệu |
| Netlist dùng **66 `dfxtp_1`** — không có chân reset | Logic reset nằm trên đường `D` của **cả 66** FF, trong đó có `x_reg`/`y_reg` 16 bit |
| Chi phí | Đáng kể hơn I03/I04 vì có nhiều FF rộng hơn |
| Nghĩa vụ tầng ngoài | Giữ `rst_n = 0` qua ≥ 1 cạnh clock. Testbench làm đúng (dòng 53–54) |

Một điểm đúng đáng ghi nhận: `x_reg <= X_INIT` được đặt ở **`S_IDLE` khi `start`**
(dòng 121), **không** ở nhánh reset (dòng 105 đặt `x_reg <= '0'`). Nghĩa là sau reset,
`x_reg = 0` chứ không phải `9949` — và điều đó **đúng**, vì `X_INIT` chỉ có nghĩa khi bắt
đầu một phép tính. Nếu ai đó đặt `X_INIT` vào nhánh reset thì `sin_out`/`cos_out` sau reset
sẽ chứa giá trị rác có vẻ hợp lệ, khó phát hiện hơn.

## 6. FSM có xử lý trạng thái bất hợp lệ không

Có — nhánh `default` (dòng 158–161) đưa `state` về `S_IDLE` và hạ `busy`. Đúng, nhưng
**chưa có ca kiểm** (⬜). Cách ép bằng `force`: xem `fsm.md` §5.

## 7. Điều khiển này **chưa** chứng minh được gì

| Chưa chứng minh | Vì sao |
|---|---|
| Đạt chu kỳ 10 ns | 🟥 **Đã chứng minh là KHÔNG** — WNS −1,27 ns; và `count[0]` (một tín hiệu **điều khiển**) đóng góp 13 % đường tới hạn |
| Bẫy `angle` không gây lỗi trong hệ thống thật | Testbench giữ `angle` cố định suốt giao dịch nên bẫy **không lộ ra** |
| Bẫy `busy`/`done` không gây lỗi | Chưa có master để mô phỏng |
| Nhánh `default` sống sót qua tổng hợp | Chưa có ca `force` |
| Ước tính “one-hot `count` giúp bao nhiêu ns” | Suy luận từ cấu trúc, chưa chạy thử |
| Không có latch ngoài ý muốn | ✅ **Đã chứng minh**: `synth_stat.txt` báo 66 FF, `Number of memories: 0`; bảng phân bố 55 loại cell không có `dlxtp`/`dlatch` |

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
