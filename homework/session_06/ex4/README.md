# Bài 4: Quản lý tiến trình nền với nohup và tín hiệu Kill

## Thông tin bài tập
- **Học viên:** Vinh Nguyen
- **Môn học:** DevOps (IT209) - Session 06
- **Đường dẫn nộp bài trên GitHub:** `homework/session_06/ex4/`
- **Kho lưu trữ GitHub:** [QuangVinh1605/IT209-SS06-BAI4](https://github.com/QuangVinh1605/IT209-SS06-BAI4)

---

## 1. Mục tiêu bài thực hành
1. **Khởi chạy tiến trình nền độc lập:** Biết cách khởi chạy script/tiến trình chạy dưới nền độc lập với phiên làm việc Terminal bằng lệnh `nohup` kết hợp toán tử `&`.
2. **Giám sát tiến trình hệ thống:** Thành thạo sử dụng các công cụ điều tra tiến trình như `ps aux`, `pgrep`, `top`/`htop`.
3. **Quản lý vòng đời tiến trình qua tín hiệu (Signals):** Hiểu rõ bản chất các tín hiệu hệ thống, sử dụng thành thạo lệnh `kill` với tín hiệu an toàn `SIGTERM (15)` và tín hiệu cưỡng chế `SIGKILL (9)`.

---

## 2. Bối cảnh & Tình huống thực tế

Trong môi trường quản trị máy chủ Linux (Production Server), các tác vụ như dịch vụ nền (daemon), cron job, script sao lưu dự phòng (backup), đồng bộ dữ liệu hoặc giám sát hệ thống (monitoring) thường cần chạy liên tục 24/7. 

Nếu ta chỉ chạy script trực tiếp trên phiên làm việc SSH hoặc Terminal:
- Khi người quản trị đóng cửa sổ Terminal, mạng bị đứt hoặc phiên SSH hết hạn (session timeout), hệ điều hành sẽ gửi tín hiệu **`SIGHUP` (Signal Hang Up - tín hiệu ngắt kết nối)** tới toàn bộ các tiến trình con thuộc phiên làm việc đó.
- Hậu quả là tiến trình giám sát sẽ lập tức bị hủy bỏ (killed).

**Giải pháp:**
- Sử dụng tiện ích **`nohup`** (no hangup) để bỏ qua tín hiệu `SIGHUP`, kết hợp ký tự **`&`** để đưa tiến trình xuống chạy nền (background).
- Định danh chính xác mã định danh tiến trình (**PID - Process ID**).
- Quản lý tắt tiến trình đúng quy chuẩn bằng tín hiệu **`SIGTERM (15)`** để dọn dẹp tài nguyên trước khi cân nhắc dùng **`SIGKILL (9)`**.

---

## 3. Mã nguồn kịch bản giám sát (`loop-monitor.sh`)

Kịch bản `loop-monitor.sh` được cấu hình để định kỳ cứ mỗi 5 giây ghi lại mốc thời gian hệ thống vào tệp nhật ký `/tmp/monitor.log`:

```bash
#!/bin/bash
# loop-monitor.sh: Ghi thoi gian he thong vao /tmp/monitor.log moi 5 giay
while true; do
    echo "System time: $(date)" >> /tmp/monitor.log
    sleep 5
done
```

### Giải thích hoạt động của script:
- `while true; do ... done`: Vòng lặp vô hạn, kịch bản sẽ chạy liên tục cho đến khi nhận được tín hiệu dừng từ hệ thống hoặc người dùng.
- `echo "System time: $(date)" >> /tmp/monitor.log`: Lấy mốc thời gian hiện tại từ lệnh `date` và bổ sung (append `>>`) một dòng mới vào tệp nhật ký `/tmp/monitor.log`.
- `sleep 5`: Tạm dừng thực thi 5 giây sau mỗi lần ghi log để tiết kiệm tài nguyên CPU.

---

## 4. Các bước triển khai & Nhật ký thực thi chi tiết

### Bước 1: Cấp quyền thực thi cho kịch bản

Trước khi khởi chạy, ta cần gán quyền thực thi (`execute`) cho tệp mã nguồn:

```bash
chmod +x homework/session_06/ex4/loop-monitor.sh
```

Kiểm tra phân quyền của tệp tin:
```bash
ls -l homework/session_06/ex4/loop-monitor.sh
```
*Kết quả:*
```text
-rwxr-xr-x 1 vinh vinh 170 Oct  5 21:27 homework/session_06/ex4/loop-monitor.sh
```

---

### Bước 2: Khởi chạy kịch bản ở chế độ nền độc lập với `nohup` và `&`

Khởi chạy script giám sát bằng lệnh:

```bash
nohup ./loop-monitor.sh > /dev/null 2>&1 &
```

*(Hoặc chạy với đường dẫn tuyệt đối/tương đối từ thư mục dự án)*:
```bash
nohup ./homework/session_06/ex4/loop-monitor.sh > /dev/null 2>&1 &
```

#### Phân tích cấu trúc câu lệnh:
1. **`nohup`** (*No Hang Up*): Ra lệnh cho hệ điều hành bỏ qua (ignore) tín hiệu ngắt kết nối `SIGHUP`. Nhờ đó, ngay cả khi người dùng đăng xuất khỏi SSH hoặc đóng cửa sổ Terminal, tiến trình vẫn tiếp tục hoạt động độc lập dưới nền.
2. **`./loop-monitor.sh`**: Đường dẫn tới kịch bản thực thi.
3. **`> /dev/null`**: Chuyển hướng luồng đầu ra tiêu chuẩn (**Standard Output - stdout**, file descriptor `1`) vào thiết bị ảo `/dev/null` (hố đen lưu trữ dữ liệu không cần thiết), tránh tạo tệp `nohup.out` mặc định.
4. **`2>&1`**: Chuyển hướng luồng đầu ra lỗi tiêu chuẩn (**Standard Error - stderr**, file descriptor `2`) về cùng địa chỉ với stdout (tức là chuyển tiếp vào `/dev/null`).
5. **`&`** (*Ampersand*): Đưa tiến trình xuống chạy dưới chế độ nền (background), trả lại dấu nhắc lệnh (prompt) ngay lập tức cho người dùng.

---

### Bước 3: Tìm số định danh tiến trình (PID) & Giám sát tiến trình

Sau khi khởi chạy, ta xác định PID của tiến trình thông qua lệnh `ps aux` hoặc `pgrep`:

#### 1. Kiểm tra bằng `ps aux`:
```bash
ps aux | grep loop-monitor.sh | grep -v grep
```
*Kết quả thực tế ghi nhận:*
```text
vinh      200519  0.0  0.0   7544  3964 pts/0    S+   21:32   0:00 /bin/bash ./loop-monitor.sh
```
> **PID ghi nhận:** `200519`  
> - `USER`: `vinh`  
> - `%CPU`: `0.0` (tiết kiệm tài nguyên)  
> - `STAT`: `S` (Sleeping do đang trong lệnh `sleep 5`)

#### 2. Kiểm tra nhanh bằng `pgrep`:
```bash
pgrep -fa loop-monitor.sh
```
*Kết quả:*
```text
200519 /bin/bash ./loop-monitor.sh
```

---

### Bước 4: Kiểm tra dữ liệu ghi nhật ký liên tục trong `/tmp/monitor.log`

Sử dụng lệnh `tail -n 10` để xem 10 dòng cuối cùng trong file log hoặc `tail -f` để theo dõi dữ liệu được ghi theo thời gian thực:

```bash
tail -n 10 /tmp/monitor.log
```

*Kết quả đầu ra ghi nhận thực tế trên hệ thống:*
```text
System time: Thứ Hai, 05 Tháng 10 năm 2026 21:32:32 +07
System time: Thứ Hai, 05 Tháng 10 năm 2026 21:32:37 +07
System time: Thứ Hai, 05 Tháng 10 năm 2026 21:32:42 +07
```

> **Nhận xét:** Cứ sau mỗi chu kỳ đúng 5 giây (`21:32:32` -> `21:32:37` -> `21:32:42`), tiến trình chạy nền đều đặn ghi một bản ghi thời gian vào tệp `/tmp/monitor.log` theo đúng thiết kế.

---

### Bước 5: Thực hiện tắt tiến trình bằng tín hiệu SIGTERM (15)

Theo chuẩn vận hành an toàn, ta luôn ưu tiên gửi tín hiệu ngắt mềm **`SIGTERM` (mã tín hiệu 15)** để tiến trình hoàn tất việc đóng file/giải phóng tài nguyên:

```bash
kill -15 200519
```

*(Hoặc sử dụng cú pháp tương đương: `kill -TERM 200519` hoặc `kill 200519` do tín hiệu 15 là mặc định).*

---

### Bước 6: Kiểm tra xác nhận tiến trình đã bị tiêu diệt hoàn toàn

Kiểm tra lại danh sách tiến trình sau khi gửi tín hiệu:

```bash
ps aux | grep loop-monitor.sh | grep -v grep
```
*Kết quả:*
```text
(Không có kết quả trả về)
```

Kiểm tra trạng thái bằng mã lệnh:
```bash
if ps -p 200519 > /dev/null; then
    echo "Tiến trình vẫn đang chạy, cần dùng: kill -9 200519"
else
    echo "Tiến trình 200519 đã kết thúc thành công với SIGTERM (-15)."
fi
```
*Kết quả đầu ra:*
```text
Tiến trình 200519 đã kết thúc thành công với SIGTERM (-15).
```

Kiểm tra lại tệp `/tmp/monitor.log`, log ngừng cập nhật ngay sau khi tiến trình nhận tín hiệu `kill -15`.

---

## 5. Phân tích chuyên sâu: Tín hiệu hệ thống & Cơ chế quản lý tiến trình

### 5.1. So sánh chi tiết SIGTERM (15) và SIGKILL (9)

| Tiêu chí so sánh | Tín hiệu SIGTERM (Mã: 15) | Tín hiệu SIGKILL (Mã: 9) |
| :--- | :--- | :--- |
| **Tên đầy đủ** | Signal Terminate | Signal Kill |
| **Đối tượng nhận tín hiệu** | Gửi trực tiếp đến tiến trình đích | Gửi trực tiếp đến Nhân hệ điều hành (Linux Kernel) |
| **Khả năng bắt (Catch/Trap)** | Tiến trình **có thể bắt** được tín hiệu này thông qua lệnh `trap` trong Bash hoặc Signal Handler trong C/Python | Tiến trình **hoàn toàn KHÔNG THỂ** bắt, chặn hay bỏ qua tín hiệu |
| **Hành vi xử lý** | **Graceful Shutdown:** Cho phép tiến trình xả buffer, đóng kết nối mạng/cơ sở dữ liệu, giải phóng lock file và tệp tin mở trước khi thoát | **Immediate Force Kill:** Kernel lập tức thu hồi CPU, RAM và giải phóng toàn bộ tiến trình ngay tức khắc |
| **Rủi ro vận hành** | An toàn, không gây hỏng hóc dữ liệu | Nguy cơ gây hỏng dữ liệu (Data Corruption) nếu tiến trình đang ghi dở tệp tin hoặc giao dịch database |
| **Nguyên tắc sử dụng** | **Ưu tiên số 1:** Luôn dùng trước để đóng tiến trình an toàn | **Lựa chọn cuối cùng:** Chỉ dùng khi tiến trình bị treo cứng (hang/zombie) và không phản hồi tín hiệu SIGTERM |

### 5.2. Các tín hiệu phổ biến khác trong Linux

| Tín hiệu | Mã | Ý nghĩa | Hành vi mặc định |
| :--- | :---: | :--- | :--- |
| **SIGHUP** | `1` | Hang Up | Báo ngắt phiên terminal; kết thúc tiến trình nếu không có `nohup` |
| **SIGINT** | `2` | Interrupt | Ngắt tiến trình bằng bàn phím (tương đương tổ hợp phím `Ctrl + C`) |
| **SIGQUIT**| `3` | Quit | Ngắt tiến trình và tạo core dump (tương đương `Ctrl + \`) |
| **SIGKILL**| `9` | Kill | Buộc dừng tiến trình ngay lập tức (không thể bắt hoặc bỏ qua) |
| **SIGTERM**| `15`| Terminate | Yêu cầu dừng tiến trình một cách lịch sự, cho phép dọn dẹp |
| **SIGTSTP**| `20`| Terminal Stop| Tạm dừng tiến trình (tương đương `Ctrl + Z`) |

---

## 6. Tổng hợp các câu lệnh tiện ích quản lý tiến trình

- **Liệt kê tiến trình:**
  ```bash
  ps aux                     # Xem toàn bộ tiến trình hệ thống
  pgrep -fa <ten_script>     # Tìm nhanh PID và dòng lệnh chạy script
  top / htop                 # Giám sát tài nguyên CPU, RAM theo thời gian thực
  ```
- **Quản lý job trong phiên:**
  ```bash
  jobs -l                    # Liệt kê các job đang chạy nền trong session hiện tại
  fg %1                      # Đưa job số 1 từ nền lên tiền cảnh (foreground)
  bg %1                      # Tiếp tục chạy job số 1 dưới nền nếu đang tạm dừng
  ```
- **Gửi tín hiệu tắt tiến trình:**
  ```bash
  kill -15 <PID>             # Dừng tiến trình nhẹ nhàng với SIGTERM
  kill -9 <PID>              # Cưỡng chế dừng tiến trình với SIGKILL
  pkill -f <ten_script>      # Gửi tín hiệu dừng theo tên/mẫu dòng lệnh
  ```

---

## 7. Kết luận
Qua bài thực hành, chúng ta đã:
1. Nắm vững kỹ thuật chạy dịch vụ độc lập với phiên làm việc bằng `nohup ... &`.
2. Theo dõi và trích xuất dữ liệu file log `/tmp/monitor.log` được tạo ra trong suốt vòng đời của tiến trình.
3. Thực hành đúng quy chuẩn DevOps: tìm kiếm chính xác PID, gửi tín hiệu ngắt an toàn `SIGTERM (15)` trước khi cân nhắc dùng `SIGKILL (9)`.
