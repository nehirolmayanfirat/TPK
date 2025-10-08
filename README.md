# TPK

<img width="503" height="336" alt="image" src="https://github.com/user-attachments/assets/01765b6a-4c8e-4a32-8d18-7394bf294f2b" />


TPK, Linux paket yöneticinizi Türkçe olarak kullanabilmenize olanak tanır.  

APT, DNF, YUM, PACMAN, ZYPPER ve APK destekler.

(İlk versiyon hiçbir yerde yayınlanmadı, GitHub üzerinden yayınlanan ilk versiyon **2.0.0**’dır.)

---

## Özellikler

- Paket indirme ve kurma (`indir`)
- Paket kaldırma (`kaldır`)
- Paket arama (`ara`)
- Paket bilgisi görüntüleme (`bilgi`)
- Paket listesini güncelleme (`guncelle`)
- Kurulu paketleri listeleme (`liste`)
- Önbellek temizleme (`temizle`)
- Renkli terminal çıktısı ve ilerleme çubuğu
- Otomatik onay modu (`--evet`)
- Türkçe karakter desteği (`kaldır` / `kaldir`)
- Sürüm bilgisi gösterimi (`versiyon` komutu)

---

## Kurulum

```bash
git clone https://github.com/nehirolmayanfirat/TPK.git
cd TPK
chmod +x tpk.sh
sudo mv tpk.sh /usr/local/bin/tpk
````

Kurulum tamamlandıktan sonra artık terminalde doğrudan `tpk` komutunu kullanabilirsin.

---

## Kullanım

```bash
tpk indir firefox
tpk kaldır firefox
tpk guncelle
tpk ara python
tpk bilgi nano
tpk liste
tpk temizle
tpk yardim
tpk versiyon
```

TPK, kullandığın Linux dağıtımını otomatik olarak algılar ve uygun paket yöneticisini (apt, dnf, yum, pacman, zypper, apk) arka planda çalıştırır.
Yani örneğin:

```bash
tpk indir firefox
```

komutu, dağıtımına göre arka planda şu komutlardan birini çalıştırır:

```bash
sudo apt install firefox
sudo dnf install firefox
sudo pacman -S firefox
sudo zypper install firefox
sudo apk add firefox
```

---

## Kaldırma

```bash
sudo rm /usr/local/bin/tpk
```

---

## Lisans

Bu proje **GPLv3** lisansı ile sunulmuştur.

---
