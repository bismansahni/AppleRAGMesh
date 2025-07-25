# AppleRAGMesh

**AppleRAGMesh** is an on-device Retrieval-Augmented Generation (RAG) system designed for the Apple ecosystem.  
It creates a **local mesh network** between your Apple devices (Mac, iPhone, iPad), allowing one device to **query documents stored on any other nearby device** — all without internet access.

---

### 💡 What It Does

- Builds a mesh using `MultipeerConnectivity` (Bluetooth / peer-to-peer Wi-Fi).
- Enables one Apple device (e.g. Mac) to **query files stored on other devices** (e.g. iPad, iPhone).
- Automatically handles document chunking, local embedding, and retrieval.
- All processing happens **on-device** — no cloud, no server, no internet.

---

### 🎥 Demo (macOS)

Currently demonstrated on **MacBook**, showcasing:
- Adding PDF/TXT files.
- Generating embeddings locally with MiniLM.
- Querying across the mesh (e.g. asking about a file that's only on another device).
- LLM answering achieved via CoreML optimized version of Mistral7B
  
📽️ **Watch Demo:**  
**[Click here for the Demo Video](https://arizonastateu-my.sharepoint.com/:v:/g/personal/bsahni_sundevils_asu_edu/EaoZ1Q-0E0JKqLUGmAtcK00BtqUf2H5Xz5yv-wQ_X-MKTw?e=FpTojN)**

---


### 📱 Extending to iPhone & iPad

- The codebase is ready to support iOS and iPadOS.
- Just add a new target for iPhone or iPad in Xcode.
- Once connected, you can **ask your Mac to query files stored only on your iPad/iPhone** — no need to touch the other device.

---

### ⚡ Why It’s Useful

Perfect for:
- When you’ve forgotten which device a file is on.
- Quickly referencing a document on another device without opening or browsing.
- Local, fast, secure retrieval in Airplane mode or without Wi-Fi.

**No internet required.**  
**No third-party servers.**  
**Just Apple devices talking directly.**

---

🛠 The most stable build ison the [`stable-version`](https://github.com/bismansahni/AppleRAGMesh/tree/stable-version) branch.
