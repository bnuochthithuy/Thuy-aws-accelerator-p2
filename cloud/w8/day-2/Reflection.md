# W8 - Day 2 Reflection (Kubernetes Fundamentals)

## Mục tiêu học tập

Tìm hiểu kiến thức nền tảng về Container và Kubernetes Orchestration. Làm quen với các khái niệm cơ bản trong Kubernetes như Pod, Service, ConfigMap, Secret và Network Policy. Cài đặt môi trường thực hành gồm Docker Desktop, Minikube và Kubectl.

## Những gì đã thực hiện

### 1. Tìm hiểu về Container và Kubernetes

* Đọc tài liệu về Container và sự khác biệt giữa Virtual Machine và Container.
* Tìm hiểu vai trò của Kubernetes trong việc quản lý và điều phối container.
* Hiểu được các lợi ích của Kubernetes như tự động triển khai, mở rộng và quản lý ứng dụng.

### 2. Tìm hiểu các thành phần cơ bản của Kubernetes

* Tìm hiểu khái niệm Pod – đơn vị triển khai nhỏ nhất trong Kubernetes.
* Tìm hiểu Service – cung cấp kết nối mạng ổn định cho Pod.
* Tìm hiểu ConfigMap và Secret để quản lý cấu hình và dữ liệu nhạy cảm.
* Tìm hiểu Network Policy để kiểm soát lưu lượng mạng giữa các Pod.

### 3. Cài đặt môi trường thực hành Kubernetes

* Cài đặt Docker Desktop.
* Cài đặt Kubectl để quản lý Kubernetes Cluster.
* Cài đặt Minikube để chạy Kubernetes trên máy cá nhân.
* Kiểm tra phiên bản các công cụ sau khi cài đặt.

### 4. Làm quen với Kubectl

* Tìm hiểu chức năng của Kubectl.
* Thực hành một số lệnh cơ bản:

```bash
kubectl version
kubectl get nodes
kubectl get pods
```

## Kiến thức đã học được

* Container giúp đóng gói ứng dụng và môi trường chạy thành một đơn vị thống nhất.
* Kubernetes là nền tảng điều phối container giúp triển khai, quản lý và mở rộng ứng dụng một cách tự động.
* Pod là đơn vị nhỏ nhất có thể triển khai trong Kubernetes.
* Service giúp cung cấp địa chỉ truy cập ổn định cho Pod.
* ConfigMap được sử dụng để lưu cấu hình ứng dụng.
* Secret được sử dụng để lưu trữ dữ liệu nhạy cảm như mật khẩu hoặc API Key.
* Network Policy giúp kiểm soát việc giao tiếp giữa các Pod trong Cluster.
* Kubectl là công cụ dòng lệnh dùng để tương tác với Kubernetes Cluster.
* Minikube cho phép chạy Kubernetes Cluster cục bộ trên máy tính cá nhân để phục vụ học tập và phát triển.

## Khó khăn gặp phải

* Có nhiều khái niệm mới trong Kubernetes nên ban đầu khá khó hình dung mối quan hệ giữa Pod, Service và các thành phần khác.
* Việc phân biệt ConfigMap và Secret còn chưa thật sự rõ ràng.
* Cần thêm thời gian thực hành để hiểu cách các thành phần Kubernetes hoạt động cùng nhau trong thực tế.

## Kế hoạch cho ngày tiếp theo

* Ôn tập lại các khái niệm Kubernetes đã học.
* Tìm hiểu thêm về Kubernetes Networking và Scaling.
* Chuẩn bị các câu hỏi liên quan đến Terraform cho buổi Live Session với mentor.
* Hoàn thành nội dung Terraform State Management, Modules và Best Practices.
* Chuẩn bị cho Online Test 1.
