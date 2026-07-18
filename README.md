# StockAlert 💊
### **Community Pharmacy Inventory, Expiry Tracker & Automated Procurement**

StockAlert is an enterprise-grade mobile application designed for community pharmacists to eliminate inventory shrink from drug expirations, streamline pharmacy sales/intakes, and automate wholesale reorder workflows.

---

## 🌟 Executive Features Matrix

### 1. **Visual Expiry Analytics Engine**
* **DateTime Lifespan Math**: Computes exact days-to-expiry in real time against the system clock.
* **Color-Coded Status Matrix**:
  * 🔴 **Expired** (`<= 0` Days Left) — Instantly flagged for safe disposal and removed from sellable stock.
  * 🟠 **Near Expiry** (`<= 90` Days Left) — Highlighted in orange to facilitate early dispensing or supplier return policies.
  * 🟢 **Healthy** (`> 90` Days Left) — Standard green status representing safe, active stock.
* **Inventory Health Progress Bar**: A stacked visual indicator on the dashboard displaying the ratio of healthy vs. expiring stock.

### 2. **Dual-Mode Barcode Scanner**
* **Dispense / Sale Mode (Red Visuals)**: Decodes a barcode, queries SQLite, decrements quantity by 1 unit, and alerts the user via a snackbar.
* **Receive / Restock Mode (Green Visuals)**: Instantly increments the scanned product's quantity by 1 unit.
* **Smart Throttling**: A 2.5-second scan cooldown prevents rapid double-scanning.
* **Auto-Registration Dialog**: If a scanned barcode is missing, prompts the user to enter details to register it.
* **Emulator Scan Simulator**: A manual scanner interface that mimics barcode scans for testing on computers without a camera.

### 3. **Deficiency Engine & Automated POs**
* **Safety Threshold Alerts**: Scans database for items where `Current Stock < Minimum Safety Stock`.
* **Smart Restock Calculations**: Suggests order numbers based on safety stock cushions (`suggestedQty = (minQuantity * 2.5) - currentQuantity`).
* **Grouped Supplier Routing**: Groups deficiencies into purchase orders (POs) by distributor (e.g., *MediDistributors*, *Apex Pharmaceutical*, *PharmaCorp*).
* **Transactional Fulfillment (Check-in)**: One tap to receive a PO automatically updates stock counts for all items in the order.

### 4. **Adaptive UI Theme**
* **Light Mode**: High-contrast teal and cyan palettes designed for daylight pharmacy environments.
* **Dark Mode**: High-fidelity dark slate background (`#121824`) with glowing emerald accents for night shifts.

---

## 💼 Core Presentation Use Cases

### 1. **Preventing Expiry Waste**
* **Problem**: Pharmacists lose thousands in capital when high-value drugs expire unnoticed on shelves.
* **Solution**: StockAlert highlights these items in the **"Urgent Action Items"** panel on the dashboard. Pharmacists can return near-expiry stock to suppliers for partial credit.

### 2. **Frictionless Sales & Inventory Checkout**
* **Problem**: Manually typing SKU codes or searching directories slows down patient service.
* **Solution**: Switch the scanner to **Dispense Mode**, scan the drug box, and it immediately adjusts stock counts in SQLite.

### 3. **Eliminating Clipboard Audits**
* **Problem**: Inventory checks are manually done on clipboards, resulting in late orders and stockouts.
* **Solution**: The **Deficiency Engine** aggregates low-stock items and builds reorder sheets grouped by wholesale supplier in 1 click.

---

## 🛠️ Technology Stack
* **Framework**: Flutter (Dart 3.x)
* **Local Database**: SQLite (`sqflite: ^2.4.0`) with transaction-aware batch operations
* **Hardware Interop**: `mobile_scanner: ^6.0.0` (Camera API Integration)
* **Design System**: Material Design 3

---

## 🚀 Quick Start Guide

### 1. **Environment Setup**
Ensure you have the Flutter SDK installed on your system. 

```bash
# Fetch dependencies
flutter pub get

# Run formatting and quality analysis checks
flutter analyze

# Run the test suite
flutter test
```

### 2. **Running the App**
To launch the app on your simulator or connected physical device:
```bash
flutter run
```

### 3. **Seed Data (Interactive on First Run)**
StockAlert seeds the local SQLite database with realistic pharmacy data, including:
* Expired Ibuprofen and Cough Syrup
* Near-Expiry Amoxicillin (45 days left)
* Healthy Metformin and Atorvastatin
* Barcode presets to test scanning immediately (e.g., scan `8801234567890` for Paracetamol)
