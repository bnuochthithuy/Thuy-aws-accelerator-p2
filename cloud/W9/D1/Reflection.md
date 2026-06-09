# Reflection D1 - GitOps & CI/CD

## 1. Hôm nay tôi học được gì?
- Tư duy chuyển đổi từ việc triển khai ứng dụng và hạ tầng thủ công (`kubectl apply`) sang tự động hóa hoàn toàn theo triết lý **GitOps**, lấy Git làm "nguồn chân lý duy nhất" (Single Source of Truth).
- Nắm bắt được cách thiết kế và kết hợp một luồng làm việc hiệu quả giữa **CI/CD (GitHub Actions)** và **GitOps controller (ArgoCD/Flux)** để đảm bảo quá trình phát hành phần mềm an toàn, minh bạch.

## 2. Các kiến thức cốt lõi (Key Takeaways)
- **Chiến lược CI/CD với GitHub Actions**:
  - **`plan-on-PR`**: Bước tường lửa an toàn. Khi có Pull Request, CI sẽ chạy lint, test, build và chạy plan (như `kustomize build` hoặc `helm template`) để review trước các thay đổi trên manifest, không đẩy thẳng vào cluster.
  - **`apply-on-merge`**: Khi PR được approve và merge, luồng xử lý sẽ chốt phiên bản và đẩy cấu hình mới nhất vào nhánh chính.
- **Công cụ GitOps (ArgoCD vs Flux)**:
  - Cả 2 đều dùng cơ chế Pull (kéo) để theo dõi Git và áp dụng vào Kubernetes.
  - ArgoCD cung cấp Dashboard UI trực quan tuyệt vời, phù hợp cho developer tự theo dõi ứng dụng. Flux thiên về CLI, tập trung vào CRD native của K8s.
- **Pattern App-of-apps**:
  - Mô hình quản lý mở rộng tuyệt vời của ArgoCD. Dùng một `Application` gốc trỏ đến thư mục chứa định nghĩa của hàng loạt `Application` con. Rất hữu ích để cài đặt hàng loạt add-ons khi bootstrap cluster mới.
- **Luồng đồng bộ (Sync Waves)**:
  - Công cụ mạnh mẽ để giải quyết bài toán "trứng và gà" (cái nào cần có trước). Ta có thể gán các wave (-1, 0, 1...) để định tuyến resource (VD: Phải tạo Namespace ở wave -1 rồi mới tạo Deployment ở wave 0).
- **Rollback theo chuẩn GitOps**:
  - Lệnh `kubectl rollout undo` nên bị loại bỏ vì phá vỡ sự đồng nhất giữa Cluster và Git (gây Out-of-Sync).
  - Chuẩn mực là thực hiện `git revert` tạo một commit đảo ngược lỗi. Hệ thống GitOps sẽ tự động phát hiện và lùi phiên bản một cách tự động, mọi lịch sử đều được vết lại rõ ràng trên Git.

## 3. Trải nghiệm & Điểm cần thực hành thêm
- Cần thực hành tự setup luồng GitHub Actions `plan-on-PR` hoàn chỉnh kết nối với kho lưu trữ manifest.
- Thử nghiệm việc cấu trúc thư mục repo cho bài Lab W9 sao cho ArgoCD dễ dàng đọc được với mô hình App-of-apps.

## 4. Kế hoạch tiếp theo (Next Steps)
- Chuyển tiếp sang tìm hiểu **D2: Observability**.
- Đọc tài liệu về SLO/SLI (Google SRE Book).
- Tìm hiểu kiến trúc OpenTelemetry (OTel SDK, Collector) và bộ ba giám sát Prometheus + Grafana + Loki.
- Nghiên cứu khái niệm cảnh báo *Multi-window burn rate alert*.
