# Bài 5: Thiết kế và Cấu hình dịch vụ Systemd Service cho ứng dụng Java

## Thông tin bài tập
- **Học viên:** Vinh Nguyen
- **Môn học:** DevOps (IT209) - Session 06
- **Đường dẫn nộp bài trên GitHub:** `homework/session_06/ex5/`
- **Kho lưu trữ GitHub:** [QuangVinh1605/IT209-SS06-BAI5](https://github.com/QuangVinh1605/IT209-SS06-BAI5)

---

## 1. Mục tiêu bài thực hành
1. **Thiết kế Systemd Service chuẩn:** Đóng gói ứng dụng chạy nền thành dịch vụ hệ thống thông qua tệp cấu hình Unit file (`java-app.service`), cho phép hệ điều hành tự động quản lý vòng đời ứng dụng.
2. **Nâng cao an ninh với Non-root System User:** Thiết lập dịch vụ vận hành dưới tài khoản hệ thống chuyên biệt (`java-runner`), không có quyền truy cập shell tương tác (`/usr/sbin/nologin`) theo nguyên tắc đặc quyền tối thiểu (*Principle of Least Privilege*).
3. **Cơ chế tự phục hồi (Self-healing):** Cài đặt chính sách tự động khởi động lại dịch vụ (`Restart=on-failure`) sau 10 giây (`RestartSec=10`) khi xảy ra sự cố đột ngột hoặc tiến trình bị crash.
4. **Tích hợp Boot & Quản lý Log:** Đăng ký kích hoạt dịch vụ cùng hệ điều hành (`systemctl enable`) và truy vấn nhật ký tập trung qua `journalctl`.

---

## 2. Bối cảnh & Tình huống thực tế

Trong môi trường triển khai ứng dụng thực tế (Production), các ứng dụng Java / Spring Boot thường được đóng gói dưới dạng tệp thực thi `.jar`.

Nếu người quản trị khởi chạy ứng dụng thủ công bằng lệnh dòng lệnh trực tiếp:
```bash
java -jar app.jar
```
hoặc kể cả chạy nền bằng:
```bash
nohup java -jar app.jar &
```
Cách tiếp cận này bộc lộ nhiều điểm hạn chế nghiêm trọng:
- **Không tự khởi động khi máy chủ reboot:** Khi máy chủ khởi động lại hoặc bảo trì, ứng dụng không thể tự động bật lên.
- **Không có cơ chế tự phục hồi:** Nếu ứng dụng gặp lỗi crash (Out of Memory - OOM, Uncaught Exception, hoặc bị kill), tiến trình sẽ dừng vĩnh viễn cho đến khi có người can thiệp thủ công.
- **Nguy cơ an ninh bảo mật cao:** Thói quen chạy ứng dụng dưới tài khoản người dùng hiện tại hoặc tài khoản `root` tạo ra lỗ hổng nghiêm trọng; nếu ứng dụng bị khai thác lỗ hổng thực thi mã từ xa (RCE), kẻ tấn công sẽ chiếm đoạt toàn quyền kiểm soát máy chủ.

**Giải pháp:** Đóng gói ứng dụng thành một dịch vụ chuẩn hóa của **Systemd** (`systemd service unit`), chạy dưới người dùng hệ thống không đặc quyền `java-runner`.

---

## 3. Khởi tạo tài khoản hệ thống không đặc quyền (`java-runner`)

Tạo tài khoản hệ thống chuyên dụng không có quyền đăng nhập shell trực tiếp:

```bash
sudo useradd -r -s /usr/sbin/nologin java-runner
```

### Phân tích các tham số:
- **`-r`** (*system account*): Tạo tài khoản hệ thống với UID < 1000 (không áp dụng chính sách hết hạn mật khẩu, dùng cho các daemon nền).
- **`-s /usr/sbin/nologin`**: Thiết lập shell đăng nhập là `/usr/sbin/nologin`. Bất kỳ nỗ lực đăng nhập nào thông qua SSH hoặc terminal tương tác đều bị từ chối, giúp triệt tiêu nguy cơ chiếm đoạt interactive shell.

### Kiểm tra kết quả tạo user:
```bash
id java-runner
grep java-runner /etc/passwd
```
*Kết quả ghi nhận trên hệ thống:*
```text
uid=994(java-runner) gid=971(java-runner) groups=971(java-runner)
java-runner:x:994:971::/home/java-runner:/usr/sbin/nologin
```

---

## 4. Tệp tin cấu hình dịch vụ Systemd (`java-app.service`)

Tệp cấu hình dịch vụ được tạo tại đường dẫn chuẩn của hệ thống: `/etc/systemd/system/java-app.service` và sao chép lưu trữ tại `homework/session_06/ex5/java-app.service`.

```ini
[Unit]
Description=Java Spring Boot Application Service
After=network.target

[Service]
Type=simple
User=java-runner
Group=java-runner
Restart=on-failure
RestartSec=10
ExecStart=/usr/bin/bash -c "echo 'Starting Java Spring Boot Application as user: '$(whoami); echo 'Application started successfully on port 8080'; exec /usr/bin/sleep 3600"

[Install]
WantedBy=multi-user.target
```

### Phân tích chi tiết cấu trúc Unit File:

#### Khối `[Unit]`
- **`Description`**: Mô tả ngắn gọn về dịch vụ, hiển thị khi truy vấn trạng thái hoặc xem nhật ký log.
- **`After=network.target`**: Xác định thứ tự khởi động phụ thuộc; dịch vụ chỉ được khởi chạy sau khi hệ thống mạng cơ bản đã sẵn sàng.

#### Khối `[Service]`
- **`Type=simple`**: Loại dịch vụ mặc định của Systemd; tiến trình được chỉ định trong `ExecStart` chính là tiến trình chính (Main PID) của dịch vụ.
- **`User=java-runner`**: Chỉ định tài khoản hệ điều hành thực thi tiến trình, cô lập hoàn toàn khỏi quyền `root`.
- **`Group=java-runner`**: Nhóm người dùng tương ứng cho tiến trình.
- **`ExecStart`**: Câu lệnh khởi chạy ứng dụng. Trong bài thực hành, tiến trình được mô phỏng xuất thông tin nhận diện tài khoản thực thi (`whoami`), thông báo khởi chạy cổng `8080`, và chạy tác vụ dài hạn bằng `exec /usr/bin/sleep 3600`.
- **`Restart=on-failure`**: Chính sách tự phục hồi: Systemd sẽ tự động khởi động lại dịch vụ nếu tiến trình kết thúc với mã lỗi khác 0, hoặc bị hủy bất thường bởi tín hiệu hệ thống (ví dụ: `SIGKILL`, `SIGSEGV`).
- **`RestartSec=10`**: Thời gian giãn cách chờ 10 giây trước khi Systemd thực hiện khởi động lại dịch vụ, giúp ngăn chặn hiện tượng lặp restart quá nhanh gây nghẽn CPU (Restart Crash Loop).

#### Khối `[Install]`
- **`WantedBy=multi-user.target`**: Chỉ định runlevel/target chuẩn cho hệ thống đa người dùng không có giao diện đồ họa (tương ứng với Runlevel 3 truyền thống). Dịch vụ sẽ tự động kích hoạt khi bật máy nếu được `enable`.

---

## 5. Nhật ký triển khai & Kiểm tra thực tế

### Bước 1: Nạp lại cấu hình Systemd Daemon
Mỗi khi tạo mới hoặc sửa đổi tệp unit service, cần yêu cầu Systemd nạp lại cấu hình:
```bash
sudo systemctl daemon-reload
```

---

### Bước 2: Kích hoạt tự khởi động cùng hệ thống (Auto-start on boot)
```bash
sudo systemctl enable java-app.service
```
*Kết quả:*
```text
Created symlink '/etc/systemd/system/multi-user.target.wants/java-app.service' → '/etc/systemd/system/java-app.service'.
```

---

### Bước 3: Khởi chạy dịch vụ
```bash
sudo systemctl start java-app.service
```

---

### Bước 4: Kiểm tra trạng thái dịch vụ (`systemctl status`)
```bash
sudo systemctl status java-app.service --no-pager
```

*Kết quả đầu ra thực tế:*
```text
● java-app.service - Java Spring Boot Application Service
     Loaded: loaded (/etc/systemd/system/java-app.service; enabled; preset: enabled)
     Active: active (running) since Mon 2026-10-05 21:38:14 +07; 41s ago
 Invocation: 7363f39f326f4b4194eb50dd8e023b8c
   Main PID: 217900 (sleep)
      Tasks: 1 (limit: 14982)
     Memory: 1.3M (peak: 2.2M)
        CPU: 21ms
     CGroup: /system.slice/java-app.service
             └─217900 /usr/bin/sleep 3600

Thg 10 05 21:38:14 vinh-ThinkPad-E15 systemd[1]: Started java-app.service - Java Spring Boot Application Service.
Thg 10 05 21:38:14 vinh-ThinkPad-E15 bash[217900]: Starting Java Spring Boot Application as user: java-runner
Thg 10 05 21:38:14 vinh-ThinkPad-E15 bash[217900]: Application started successfully on port 8080
```

> **Đánh giá:** Dịch vụ đạt trạng thái **`Active: active (running)`**, có tiến trình chính PID là `217900`, được quản lý bởi CGroup `/system.slice/java-app.service`.

---

### Bước 5: Truy vấn nhật ký hệ thống qua `journalctl`
Truy vấn log tập trung của dịch vụ:
```bash
sudo journalctl -u java-app.service --no-pager -n 20
```

*Kết quả đầu ra thực tế:*
```text
Thg 10 05 21:37:41 vinh-ThinkPad-E15 systemd[1]: Started java-app.service - Java Spring Boot Application Service.
Thg 10 05 21:37:41 vinh-ThinkPad-E15 bash[216203]: Starting Java Spring Boot Application as user: java-runner
Thg 10 05 21:37:41 vinh-ThinkPad-E15 bash[216203]: Application started successfully on port 8080
```

> **Minh chứng rõ ràng:** Dòng log `Starting Java Spring Boot Application as user: java-runner` chứng minh tiến trình hoàn toàn chạy dưới định danh người dùng không đặc quyền **`java-runner`**.

---

### Bước 6: Thực nghiệm kiểm chứng chính sách phục hồi lỗi (`Restart=on-failure` & `RestartSec=10`)

Để chứng minh khả năng tự phục hồi, ta tiến hành gửi tín hiệu `SIGKILL` (mô phỏng ứng dụng bị crash đột ngột do lỗi phần mềm hoặc OOM):

1. **Gửi tín hiệu ép dừng tiến trình:**
   ```bash
   sudo kill -9 216203
   ```

2. **Kiểm tra trạng thái ngay sau khi crash (sau 2 giây):**
   ```text
   ● java-app.service - Java Spring Boot Application Service
        Loaded: loaded (/etc/systemd/system/java-app.service; disabled; preset: enabled)
        Active: activating (auto-restart) (Result: signal) since Mon 2026-10-05 21:38:04 +07; 2s ago
       Process: 216203 ExecStart=... (code=killed, signal=KILL)
      Main PID: 216203 (code=killed, signal=KILL)
   ```
   > **Nhận xét:** Systemd phát hiện tiến trình bị dừng bởi tín hiệu (`Result: signal`) và chuyển sang trạng thái chờ kích hoạt lại: **`activating (auto-restart)`**.

3. **Kiểm tra trạng thái sau 10 giây (`RestartSec=10`):**
   ```text
   Thg 10 05 21:38:04 vinh-ThinkPad-E15 systemd[1]: java-app.service: Main process exited, code=killed, status=9/KILL
   Thg 10 05 21:38:04 vinh-ThinkPad-E15 systemd[1]: java-app.service: Failed with result 'signal'.
   Thg 10 05 21:38:14 vinh-ThinkPad-E15 systemd[1]: java-app.service: Scheduled restart job, restart counter is at 1.
   Thg 10 05 21:38:14 vinh-ThinkPad-E15 systemd[1]: Started java-app.service - Java Spring Boot Application Service.
   Thg 10 05 21:38:14 vinh-ThinkPad-E15 bash[217900]: Starting Java Spring Boot Application as user: java-runner
   Thg 10 05 21:38:14 vinh-ThinkPad-E15 bash[217900]: Application started successfully on port 8080
   ```
   > **Kết quả:** Đúng 10 giây sau thời điểm crash (`21:38:04` -> `21:38:14`), Systemd đã tự động khởi chạy lại dịch vụ với PID mới (`217900`), đưa hệ thống trở lại trạng thái `active (running)` một cách tự động và ổn định.

---

## 6. Phân tích nguyên tắc an toàn & Lợi ích kiến trúc Systemd

### 6.1. Nguyên tắc đặc quyền tối thiểu (Least Privilege)
- Chạy ứng dụng dưới quyền `root` tiềm ẩn nguy cơ bảo mật nghiêm trọng. Nếu có lỗ hổng Deserialization hoặc Remote Code Execution (RCE) trong ứng dụng Java, kẻ tấn công có thể ghi đè file hệ thống, cài mã độc rootkit.
- Khi giới hạn với `User=java-runner` kết hợp shell `/usr/sbin/nologin`, phạm vi truy cập bị thu hẹp tối đa:
  - Không thể đăng nhập vào shell.
  - Không thể chỉnh sửa các tệp tin hệ thống ngoài thư mục được cấp quyền.
  - Giảm thiểu tối đa bán kính thiệt hại (Blast Radius) khi xảy ra sự cố bảo mật.

### 6.2. So sánh các cơ chế Restart trong Systemd

| Giá trị `Restart` | Hành vi | Trường hợp sử dụng phù hợp |
| :--- | :--- | :--- |
| **`no`** (mặc định) | Không tự khởi động lại trong mọi trường hợp | Tác vụ chạy một lần (One-shot batch job) |
| **`always`** | Luôn tự khởi động lại dù tiến trình thoát bình thường hay gặp lỗi | Dịch vụ bắt buộc luôn online 24/7 |
| **`on-failure`** | Chỉ khởi động lại khi tiến trình thoát với mã lỗi khác 0 hoặc bị kill bởi tín hiệu | **Dịch vụ chuẩn Production (Java, NodeJS, Golang)** |
| **`on-abnormal`** | Chỉ khởi động lại khi bị kill bởi tín hiệu, timeout hoặc watchdog | Dịch vụ cần phân biệt giữa crash và exit lỗi bình thường |

---

## 7. Tổng kết các lệnh quản lý dịch vụ Systemd thường dùng

```bash
# Nạp lại cấu hình sau khi sửa file .service
sudo systemctl daemon-reload

# Bật/Tắt chế độ tự khởi động cùng hệ thống
sudo systemctl enable java-app.service
sudo systemctl disable java-app.service

# Khởi chạy / Tạm dừng / Khởi động lại dịch vụ
sudo systemctl start java-app.service
sudo systemctl stop java-app.service
sudo systemctl restart java-app.service

# Kiểm tra trạng thái chi tiết
sudo systemctl status java-app.service

# Xem nhật ký log thời gian thực
sudo journalctl -u java-app.service -f
```
