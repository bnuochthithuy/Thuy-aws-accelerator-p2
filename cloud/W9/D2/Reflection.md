# Reflection D2 - Observability: SLO/SLI & OTel

## 1. Hôm nay tôi học được gì?
- Hiểu được bức tranh toàn cảnh về **Observability (Giám sát và Quan sát hệ thống)** không chỉ dừng lại ở việc thiết lập công cụ hay vẽ biểu đồ (dashboard), mà là tư duy xây dựng hệ thống có khả năng tự "kể" về tình trạng sức khỏe thực sự của nó.
- Chuyển dịch tư duy giám sát từ cách làm cũ (chỉ nhìn vào CPU/RAM hạ tầng) sang triết lý **SRE của Google**: tập trung vào sự hài lòng và trải nghiệm thực tế của người dùng thông qua **SLO/SLI** và khái niệm **Error Budget** (Ngân sách lỗi).
- Nắm bắt được tiêu chuẩn công nghiệp mới **OpenTelemetry (OTel)** và vai trò của bộ ba "huyền thoại" mã nguồn mở: Prometheus, Loki, Grafana.

## 2. Các kiến thức cốt lõi (Key Takeaways)
- **Kiến trúc OpenTelemetry (OTel)**:
  - Tiêu chuẩn mở hợp nhất việc thu thập 3 trụ cột (Metrics, Logs, Traces).
  - **OTel SDK**: Các thư viện cài đặt trực tiếp vào ứng dụng để tự động phát dữ liệu (instrumentation).
  - **OTel Collector**: Trạm trung chuyển (nhận -> xử lý -> xuất dữ liệu). Nó giúp ứng dụng hoàn toàn độc lập (decouple) với hệ thống lưu trữ đích (như Prometheus). Đổi tool backend không cần sửa code ứng dụng.
- **Bộ 3 công cụ lưu trữ & hiển thị**:
  - **Prometheus**: Cơ sở dữ liệu chuỗi thời gian (Time-series DB), hoạt động theo cơ chế Pull, chuyên lưu Metrics.
  - **Loki**: Giải pháp lưu trữ Logs nhẹ nhàng, chia sẻ chung hệ thống đánh nhãn (labels) với Prometheus giúp việc tra cứu liên kết cực kỳ dễ dàng.
  - **Grafana**: Giao diện tổng hợp vẽ dashboard và truy vấn dữ liệu từ cả Prometheus và Loki.
- **Phương pháp luận đo lường (SLO/SLI)**:
  - **SLI (Indicator - Chỉ số)**: Phép đo hiệu năng thực tế. Quan trọng nhất là *Availability* (tỷ lệ request HTTP thành công) và *Latency* (thời gian phản hồi, ví dụ: p99 < 200ms).
  - **SLO (Objective - Mục tiêu)**: Cam kết nội bộ (ví dụ: Availability 99.9%). Khoảng chênh lệch (0.1%) chính là *Error Budget* - quỹ lỗi cho phép hệ thống "xả hơi" hoặc thực hiện cập nhật có rủi ro.
- **Cảnh báo tốc độ đốt cháy ngân sách (Multi-window burn rate alert)**:
  - Triết lý cảnh báo thông minh chống lại "Alert Fatigue" (Hội chứng kiệt sức vì báo động giả).
  - Thay vì báo ngay khi có lỗi, hệ thống đo lường **Burn rate**:
    - **Fast burn (Đốt cực nhanh)**: Tính trên cửa sổ kép (1h × 5m). Lỗi nghiêm trọng, đốt sạch ngân sách trong vài giờ $\rightarrow$ Báo động đỏ (PagerDuty / Gọi điện) ngay lập tức.
    - **Slow burn (Đốt chậm)**: Tính trên cửa sổ kép (6h × 30m). Lỗi rỉ rả, từ từ xói mòn ngân sách trong vài ngày $\rightarrow$ Mở Ticket (Jira) để xử lý trong giờ hành chính, không gọi ai dậy ban đêm.

## 3. Trải nghiệm & Điểm cần thực hành thêm
- Cấu trúc file cấu hình (pipeline: receivers, processors, exporters) của OTel Collector còn khá lạ lẫm, cần vọc thêm trên môi trường lab.
- Viết câu truy vấn (PromQL) cho Prometheus để tính toán chính xác SLI đòi hỏi phải hiểu rõ bản chất của các metrics counter/histogram.

## 4. Kế hoạch tiếp theo (Next Steps)
- Sang ngày **D3: Tiến tới Progressive Delivery (Canary)**.
- Tìm hiểu **Argo Rollouts** (bản nâng cấp của Kubernetes Deployment).
- Tìm cách ứng dụng kiến thức Metrics/Prometheus của ngày D2 vào `AnalysisTemplate` của Argo Rollouts. Mục tiêu là: dùng metric để chấm điểm, nếu lỗi tăng (burn rate cao) thì tự động huỷ bỏ (auto-abort) bản Canary deployment mới.
