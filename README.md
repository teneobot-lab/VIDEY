# PIDI

Repository untuk project modular TOFHub.

## Menjalankan (GitHub raw loader)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/teneobot-lab/PIDI/main/loader.lua"))()
```

`loader.lua` mengunduh `TOFHub/main.lua` lalu mengaktifkan mode online, sehingga semua modul diambil dari folder `TOFHub/` di repo ini.
Repo lain / branch lain: set `getgenv().PIDI_REPO = {user="...", repo="...", branch="main"}` sebelum menjalankan loader.

## Vault Logger (skrip mandiri)

Hanya merekam (tidak mengubah game), untuk melihat cara kerja vault jendela. Tidak butuh TOFHub:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/teneobot-lab/VIDEY/main/TOFHub/tools/VaultLogger.lua"))()
```

Tekan Mulai, vault jendela, hasil otomatis disalin ke clipboard (dan disimpan ke `VaultLog.txt`).

## Catatan

- `TOFHub.zip` dan workflow `extract-tofhub.yml` menimpa folder `TOFHub/` setiap push ke `main`. Zip ini sudah berisi versi terbaru; jika mengubah file di `TOFHub/` langsung, perbarui zip-nya juga (atau hapus workflow) supaya perubahan tidak tertimpa.
- Satu file: `python3 TOFHub/build.py` menghasilkan `TOFHub_bundle.lua`.
