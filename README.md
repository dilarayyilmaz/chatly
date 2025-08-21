# 💬 Chatly

**Chatly** is a real-time messaging application inspired by WhatsApp.  
It allows users to chat one-on-one or in groups, share media, and stay connected through a modern and reliable platform.

---

## 🚀 Features
**Core**
- 1️⃣ One-on-one messaging  
- 👥 Group chats (create/invite members)  
- 🔐 User authentication (email/password or Google/Apple sign-in)  
- 🕒 Real-time messaging (via Firebase or Socket.IO)  
- ✅ Read receipts (single/double checkmarks) & typing indicators  
- 🖼️ Media sharing (images, videos, files)  



## 🧱 Architecture
- **Client:** Flutter (Dart) – cross-platform (Android, iOS, Web)  
- **Real-time backend:**  
   **Firebase** (Auth, Firestore/Realtime DB, Cloud Storage, FCM)  
   **Node.js + Socket.IO** (with Redis optional), S3/Cloud Storage for media  
---

## 🛠️ Technologies
- Flutter (Dart)  
- Firebase (Auth, Firestore/RTDB, Storage, FCM) **or** Node.js + Socket.IO  
