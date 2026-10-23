# I05 · Máy trạng thái (FSM)

I05 **có** FSM. Đọc từ `i05_cordic_core.sv` dòng 26–32 (khai báo) và 117–162 (thân `case`).

---

## 1. Khai báo trong RTL

```systemverilog
typedef enum logic [1:0] {
    S_IDLE,     // = 2'b00
    S_ITER,     // = 2'b01
    S_DONE      // = 2'b10
} state_t;

state_t state;
```

| Hạng mục | Giá trị |
|---|---|
| Số trạng thái dùng | 3 |
| Độ rộng | 2 bit → 4 mã, **1 mã thừa** (`2'b11`) |
| Mã hoá | **Nhị phân** |
| Bằng chứng sau tổng hợp | `netlist.v` có đúng **2** `dfxtp_1` tên `state[0]`, `state[1]` ⟹ Yosys giữ nguyên mã nhị phân |

## 2. Mealy hay Moore — và bằng chứng

**Kết luận: FSM của I05 là Moore có đầu ra đã đăng ký (registered Moore).**

| Tiêu chí | Quan sát trong RTL | Kết luận |
|---|---|---|
| `busy`, `done` phụ thuộc gì? | Chỉ `state` và `count` (thanh ghi) | Không Mealy |
| Đầu ra có qua flip-flop? | `busy`, `done`, `sin_out`, `cos_out` đều gán bằng `<=` trong `always_ff` | Moore có đăng ký |
| `start` có đường tổ hợp ra cổng ra? | Không | Xác nhận Moore |

> ⚠️ **Nhưng có một sắc thái riêng của I05 mà I03/I04 không có.** `sin_out`/`cos_out` phụ
> thuộc tổ hợp vào **`angle`** (qua `sign_cos`/`sign_sin`, dòng 74–90 và 139–144). Về hình
> thức đây vẫn là Moore (đầu ra đã đăng ký), nhưng về **thực chất** nó tạo một đường
> **input-to-register dài**: `angle → so sánh → sign_* → đổi dấu → sin_out`. Đường này:
>
> - cần `set_input_delay` đúng để STA phân tích được (SDC hiện đặt 1,0 ns — **giả định**);
> - tạo ràng buộc ngầm: `angle` phải ổn định **suốt 9 chu kỳ** (xem `control.md` §4, bẫy 2).
>
> Khi bảo vệ, nếu bị hỏi *“FSM này Mealy hay Moore?”* thì câu trả lời đầy đủ là:
> **“Moore về đầu ra điều khiển (`busy`, `done`); còn `sin_out`/`cos_out` tuy cũng đã đăng
> ký nhưng nhận một đường tổ hợp dài từ cổng vào `angle` — đó là chỗ cần cẩn thận.”**

## 3. Sơ đồ trạng thái

```
                         rst_n = 0 (đồng bộ)
                    ┌──────────────────────────────┐
                    ▼                              │
            ╔═══════════════╗                      │
            ║    S_IDLE     ║                      │
     ┌─────▶║    2'b00      ║                      │
     │      ║  busy ← 0     ║                      │
     │      ╚═══╤═══════╤═══╝                      │
     │  start=0 │       │ start=1                  │
     │  (tự lặp)└───────┤  NẠP: x_reg ← 9949       │
     │                  │       y_reg ← 0          │
     │                  │       z_reg ← z_init     │
     │                  │       count ← 0, busy←1  │
     │                  ▼                          │
     │          ╔════════════════════════╗         │
     │          ║       S_ITER           ║◀──┐     │
     │          ║       2'b01            ║   │ count != 7
     │          ║  busy ← 1              ║   │ (count←count+1)
     │          ║  x,y,z ← x,y,z_next    ║───┘     │
     │          ║  chiều quay do z_reg[9]║         │
     │          ╚═══════════╤════════════╝         │
     │                      │ count == 7            │
     │                      │ cos_out ← ±quantize(x_next)
     │                      │ sin_out ← ±quantize(y_next)
     │                      │ busy ← 0              │
     │                      ▼                       │
     │          ╔═══════════════╗                   │
     │          ║    S_DONE     ║                   │
     └──────────║    2'b10      ║                   │
                ║  done ← 1     ║  ← 🟡 chỉ làm MỖI việc này
                ╚═══════════════╝                   │
                                                    │
            ╔═══════════════╗                       │
            ║  2'b11 (thừa) ║──── default ──────────┘
            ╚═══════════════╝
```

> 🟡 **`S_DONE` đang bị bỏ phí.** Nó tồn tại đúng một chu kỳ và chỉ để phát `done`. Trong
> khi đó, khâu `quantize_q14` (làm tròn + bão hoà + đổi dấu) — đoạn chiếm **35 %** đường
> tới hạn — lại bị nhồi vào `S_ITER` ở `count == 7`. Chuyển nó sang `S_DONE` sẽ **không
> tốn thêm chu kỳ nào** mà rút được ≈ 3,88 ns. Đây là quan sát kiến trúc quan trọng nhất
> của đề, và nó nhìn ra được **chỉ bằng cách đọc sơ đồ trạng thái**. Xem `tradeoff.md` §7.

## 4. Bảng chuyển trạng thái đầy đủ

| # | Trạng thái | `rst_n` | `start` | `count` | Kế tiếp | Đầu ra / tác động |
|---|---|:-:|:-:|---|---|---|
| 1 | bất kỳ | **0** | × | × | `S_IDLE` | Xoá đồng bộ: `x_reg←0`, `y_reg←0`, `z_reg←0`, `count←0`, `sin_out←0`, `cos_out←0`, `busy←0`, `done←0` |
| 2 | `S_IDLE` | 1 | 0 | × | `S_IDLE` | `busy←0`, `done←0` |
| 3 | `S_IDLE` | 1 | **1** | × | `S_ITER` | `x_reg←X_INIT (9949)`, `y_reg←0`, `z_reg←z_init`, `count←0`, `busy←1` |
| 4 | `S_ITER` | 1 | × | `≠ 7` | `S_ITER` | `busy←1`, `count←count+1`, `x_reg←x_next`, `y_reg←y_next`, `z_reg←z_next` |
| 5 | `S_ITER` | 1 | × | **`==7`** | `S_DONE` | `cos_out←sign_cos ? −quantize(x_next) : quantize(x_next)`; `sin_out` tương tự với `y_next`; `busy←0`; (`count` **không** tăng); `x,y,z_reg` vẫn được cập nhật |
| 6 | `S_DONE` | 1 | × | × | `S_IDLE` | `busy←0`, **`done←1`** |
| 7 | `2'b11` | 1 | × | × | `S_IDLE` | `busy←0` (nhánh `default`) |

Cột `start` mang dấu `×` ở dòng 4–6 ⟹ **giao dịch không thể bị ngắt** (INV-8).

## 5. Xử lý trạng thái bất hợp lệ

| Hạng mục | Trạng thái |
|---|---|
| Nhánh `default` | ✅ Có (dòng 158–161): `busy ← 0`, `state ← S_IDLE` |
| Pragma `full_case`/`parallel_case` | ❌ Không dùng — tốt |
| Còn sau tổng hợp? | ⚠️ **Chưa kiểm** |
| Có ca kiểm? | ⬜ **Chưa có** |

```systemverilog
force  i05_cordic_core_tb.dut.state = 2'b11;
@(posedge clk);
release i05_cordic_core_tb.dut.state;
@(posedge clk);
assert (dut.state == 2'b00) else $fatal(1, "FSM khong phuc hoi tu 2'b11");
```

## 6. Vì sao 3 trạng thái là đủ — và vì sao **không** nên trải vòng lặp

| Phương án | Trạng thái | FF điều khiển | Bộ dịch | Bộ cộng | Nhận xét |
|---|---:|---:|---|---|---|
| **Đã chọn:** `IDLE/ITER/DONE` + `count` | 3 | 2 + 4 = **6** | **Biến thiên** (77 mux) | **3** bộ, dùng lại 8 lần | Diện tích nhỏ; nhưng `count` fanout 42 và bộ dịch biến thiên là nút thắt |
| Trải 8 vòng thành trạng thái `IT0…IT7` | 10 | 4 | vẫn biến thiên nếu chung phần cứng | 3 | +2 FF, **không** giải quyết được gì |
| **Trải hoàn toàn (unroll)** — 8 bản sao phần cứng | 2 | 1 | **Hằng số — 0 cell!** | **24** bộ | Bộ dịch miễn phí, đường tới hạn ngắn **nếu chia ống**; nhưng diện tích ≈ **8×** |

> 🔎 **Điểm đáng bàn nhất của I05:** ở I03 và I04, việc lặp giúp tiết kiệm bộ cộng và
> **không** tốn gì thêm (dịch hằng số = 0 cell). Ở I05, việc lặp **phải trả thêm giá**:
> vì lượng dịch thay đổi theo vòng, ta buộc phải có **bộ dịch biến thiên** — **77 cell mux**
> mà kiến trúc trải phẳng hoàn toàn không cần. Đây là một đánh đổi **không hiển nhiên**, và
> nó giải thích vì sao I05 có 864 cell trong khi I03 chỉ có 309.

## 7. Đối chiếu FSM với báo cáo công suất

`power_report.txt`:

| Nhóm | I05 | I03 | I04 |
|---|---:|---:|---:|
| Sequential | **40,3 %** | 92,3 % | 88,4 % |
| **Combinational** | **59,7 %** | 7,7 % | 11,6 % |
| Tổng | **8,10e-04 W** | 2,93e-04 W | 2,36e-04 W |

**I05 là đề duy nhất trong nhóm I mà phần tổ hợp tiêu thụ nhiều hơn phần tuần tự.** Ba lý
do, đều suy được từ cấu trúc:

1. **Không có vòng rỗng.** Ở I03, `acc_reg` đứng yên ở các vòng có bit 0; ở I04 có tới 7/8
   vòng `NOP` với `0xFF`. Ở CORDIC, **cả ba** bộ cộng chạy và **cả hai** bộ dịch chuyển
   mạch ở **mọi** vòng.
2. **Bộ dịch biến thiên chuyển mạch toàn bộ.** Khi `count` tăng, toàn bộ 32 bit dữ liệu
   dịch qua mạng mux ⟹ hoạt động rất cao.
3. **Diện tích tổ hợp lớn:** 864 − 66 = **798 cell tổ hợp**, so với 245 của I03.

⚠️ Nhưng vẫn phải nhắc: báo cáo công suất này là **ước lượng với hoạt động mặc định**,
**không** lấy từ VCD. Muốn số thật cần mô phỏng có `$dumpvars` rồi `read_vcd` — ⬜ **chưa chạy**.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
