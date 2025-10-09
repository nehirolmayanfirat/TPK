#!/usr/bin/env bash
set -euo pipefail

# tpk, ilk sürüm. bulduğunuz hataları lütfen bildirib!

readonly TPK_VERSION="2.0.1"
readonly REQUIRED_BASH_VERSION=4

if (( BASH_VERSINFO[0] < REQUIRED_BASH_VERSION )); then
  printf '\e[31mHata: Bu betik bash %d.0+ gerektirir. Mevcut: %s\e[0m\n' \
    "$REQUIRED_BASH_VERSION" "${BASH_VERSION}" >&2
  exit 1
fi


readonly RENK_YESIL="\e[32m"
readonly RENK_KIRMIZI="\e[31m"
readonly RENK_SARI="\e[33m"
readonly RENK_MAVI="\e[36m"
readonly RENK_MOR="\e[35m"
readonly RENK_BEYAZ="\e[37m"
readonly RENK_GRI="\e[90m"
readonly RENK_SIFIRLA="\e[0m"


readonly LOG_DIZIN="${XDG_STATE_HOME:-$HOME/.local/state}/tpk"
readonly LOG_DOSYA="$LOG_DIZIN/tpk.log"
readonly CACHE_DIZIN="${XDG_CACHE_HOME:-$HOME/.cache}/tpk"

mkdir -p "$LOG_DIZIN" "$CACHE_DIZIN" 2>/dev/null || true

TMP_FILES=()
ERROR_LOG=""
PROG_PID=""
OTOMATIK_ONAY=0
USE_SUDO=0
VERBOSE=0


mktemp_reg() {
    local f
    if ! f="$(mktemp -p "${TMPDIR:-/tmp}" tpk.XXXXXX 2>/dev/null)"; then
        printf '%bHata: Geçici dosya oluşturulamadı%b\n' "$RENK_KIRMIZI" "$RENK_SIFIRLA" >&2
        return 1
    fi
    TMP_FILES+=("$f")
    printf '%s' "$f"
}


TERM_WIDTH="${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}"
BAR_WIDTH=$(( TERM_WIDTH > 80 ? 50 : TERM_WIDTH - 30 ))
BAR_WIDTH=$(( BAR_WIDTH < 20 ? 20 : BAR_WIDTH ))


renk_gecis() {
    local metin="$1"
    local palet=("\e[38;5;81m" "\e[38;5;117m" "\e[38;5;153m" "\e[38;5;189m")
    local pcount=${#palet[@]}
    local i=0
    
    for ((idx=0; idx<${#metin}; idx++)); do
        printf "%b%c" "${palet[i]}" "${metin:idx:1}"
        i=$(( (i+1) % pcount ))
    done
    printf "%b\n" "$RENK_SIFIRLA"
}


kutu_yaz() {
    local renk="${1:-$RENK_BEYAZ}"
    shift
    local mesaj="$*"
    
    [[ -z "$mesaj" ]] && return
    
    mapfile -t satirlar <<< "$mesaj"
    local max=0
    
    for satir in "${satirlar[@]}"; do
        local len=${#satir}
        (( len > max )) && max=$len
    done
    
    local ust="┌" alt="└"
    for ((i=0; i<max+2; i++)); do
        ust+="─"
        alt+="─"
    done
    ust+="┐"
    alt+="┘"
    
    printf "%b%s%b\n" "$renk" "$ust" "$RENK_SIFIRLA"
    
    for satir in "${satirlar[@]}"; do
        local pad=$((max - ${#satir}))
        printf "%b│ %s%*s │%b\n" "$renk" "$satir" "$pad" "" "$RENK_SIFIRLA"
    done
    
    printf "%b%s%b\n" "$renk" "$alt" "$RENK_SIFIRLA"
}


progress_runner() {
    local width="$1" interval="${2:-0.12}"
    local p=0
    local chars=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local char_idx=0
    
    while true; do
        local filled=$(( (p * width) / 100 ))
        local empty=$(( width - filled ))
        local bar=""
        
        for ((i=0; i<filled; i++)); do bar+="█"; done
        for ((i=0; i<empty; i++)); do bar+="░"; done
        
        printf "\r%b %s [%s] %3d%%%b" \
            "$RENK_SARI" "${chars[char_idx]}" "$bar" "$p" "$RENK_SIFIRLA"
        
        sleep "$interval"
        p=$((p + (RANDOM % 5) + 2))
        (( p > 98 )) && p=98
        char_idx=$(( (char_idx + 1) % ${#chars[@]} ))
    done
}


ilerleme_cubugu_baslat() {
    local mesaj="${1:-İşlem}"
    printf "%b%s...%b\n" "$RENK_MAVI" "$mesaj" "$RENK_SIFIRLA"
    
    ( progress_runner "$BAR_WIDTH" 0.1 ) &
    PROG_PID=$!
    sleep 0.05
}


ilerleme_cubugu_durdur() {
    if [[ -n "${PROG_PID:-}" ]] && kill -0 "$PROG_PID" 2>/dev/null; then
        kill "$PROG_PID" 2>/dev/null || true
        wait "$PROG_PID" 2>/dev/null || true
        PROG_PID=""
        
        local bar=""
        for ((i=0; i<BAR_WIDTH; i++)); do bar+="█"; done
        printf "\r%b ✓ [%s] 100%%%b\n\n" "$RENK_YESIL" "$bar" "$RENK_SIFIRLA"
    fi
}


cleanup() {
    ilerleme_cubugu_durdur 2>/dev/null || true
    
    for f in "${TMP_FILES[@]:-}"; do
        [[ -e "$f" ]] && rm -f "$f" 2>/dev/null || true
    done
    
    TMP_FILES=()
}

trap cleanup EXIT INT TERM


logla() {
    local seviye="${1:-INFO}"
    shift
    local mesaj="$*"
    printf '[%s] [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$seviye" "$mesaj" >> "$LOG_DOSYA" 2>/dev/null || true
}


normalize_komut() {
    local s="${1,,}"
    
    s="${s//ı/i}"
    s="${s//ü/u}"
    s="${s//ö/o}"
    s="${s//ç/c}"
    s="${s//ğ/g}"
    s="${s//ş/s}"
    
    printf '%s' "$s"
}


paket_yoneticisini_bul() {
    local yoneticiler=(apt dnf yum pacman zypper apk)
    
    for pm in "${yoneticiler[@]}"; do
        if command -v "$pm" &>/dev/null; then
            printf '%s' "$pm"
            return 0
        fi
    done
    
    return 1
}


onay_iste() {
    local soru="$1"
    local varsayilan="${2:-e}"
    local cevap
    
    while true; do
        printf "%b%s (E/h) [%s]:%b " "$RENK_SARI" "$soru" "$varsayilan" "$RENK_SIFIRLA"
        
        if ! read -r cevap; then
            printf "\n"
            return 1
        fi
        
        cevap="${cevap:-$varsayilan}"
        
        case "${cevap,,}" in
            e|evet|yes|y) return 0 ;;
            h|hayir|no|n) return 1 ;;
            *) printf "%bLütfen E veya h girin.%b\n" "$RENK_MOR" "$RENK_SIFIRLA" ;;
        esac
    done
}


ekran_ozeti() {
    local komut_str="$1"
    local sure="$2"
    local durum="$3"
    local renk ikon
    
    case "$durum" in
        basarili)
            renk="$RENK_YESIL"
            ikon="✓"
            ;;
        hata)
            renk="$RENK_KIRMIZI"
            ikon="✗"
            ;;
        uyari)
            renk="$RENK_SARI"
            ikon="⚠"
            ;;
        *)
            renk="$RENK_MAVI"
            ikon="ℹ"
            ;;
    esac
    
    printf "\n%b━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n" "$RENK_GRI" "$RENK_SIFIRLA"
    printf "%b%s İŞLEM ÖZETİ%b\n" "$renk" "$ikon" "$RENK_SIFIRLA"
    printf "%b━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n" "$RENK_GRI" "$RENK_SIFIRLA"
    printf "Komut  : %s\n" "$komut_str"
    printf "Süre   : %ss\n" "$sure"
    printf "Durum  : %b%s%b\n" "$renk" "$durum" "$RENK_SIFIRLA"
    printf "%b━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n\n" "$RENK_GRI" "$RENK_SIFIRLA"
    
    logla "$durum" "Komut: $komut_str | Süre: ${sure}s"
}


yardim_goster() {
    cat <<EOF

$(renk_gecis "TPK - TÜRKÇE PAKET KÖPRÜSÜ v${TPK_VERSION}")

Kullanım: tpk [seçenekler] <komut> [paket...]

${RENK_MAVI}KOMUTLAR:${RENK_SIFIRLA}
  indir <paket...>     Paket(ler) indir ve kur
  kaldır <paket...>    Paket(ler) kaldır
  guncelle             Paket listesini güncelle
  ara <kelime>         Paket ara
  bilgi <paket>        Paket bilgisi göster
  liste                Kurulu paketleri listele
  temizle              Önbellek ve gereksiz paketleri temizle
  yardim               Bu yardım mesajını göster
  versiyon             Sürüm bilgisi göster

${RENK_MAVI}SEÇENEKLER:${RENK_SIFIRLA}
  -e, --evet           Tüm onayları otomatik kabul et
  -v, --verbose        Detaylı çıktı göster
  -h, --yardim         Yardım mesajını göster

${RENK_MAVI}ÖRNEKLER:${RENK_SIFIRLA}
  tpk indir vim
  tpk -e indir nginx docker
  tpk kaldır firefox
  tpk ara python
  tpk guncelle

${RENK_GRI}Desteklenen paket yöneticileri: apt, dnf, yum, pacman, zypper, apk${RENK_SIFIRLA}

EOF
}


komutu_calistir() {
    if [[ -z "${komut_dizisi+x}" ]] || [[ ${#komut_dizisi[@]} -eq 0 ]]; then
        kutu_yaz "$RENK_KIRMIZI" "Hata: Çalıştırılacak komut tanımlanmamış"
        return 1
    fi
    
    local exec_arr=()
    local komut_str ekran_metni tmpout basla bitis sure
    
    if (( USE_SUDO == 1 )); then
        exec_arr=(sudo "${komut_dizisi[@]}")
    else
        exec_arr=("${komut_dizisi[@]}")
    fi
    
    komut_str="${exec_arr[*]}"
    ekran_metni="${EKRAN_METNI:-İşlem}"
    
    tmpout="$(mktemp_reg)" || return 1
    
    (( VERBOSE == 1 )) && printf "%bKomut: %s%b\n" "$RENK_GRI" "$komut_str" "$RENK_SIFIRLA"
    
    logla "INFO" "Başlatılıyor: $komut_str"
    
    basla=$(date +%s)
    
    ilerleme_cubugu_baslat "$ekran_metni"
    
    if "${exec_arr[@]}" >"$tmpout" 2>"$ERROR_LOG"; then
        ilerleme_cubugu_durdur
        bitis=$(date +%s)
        sure=$((bitis - basla))
        
        kutu_yaz "$RENK_YESIL" "✓ İşlem başarıyla tamamlandı"
        
        if [[ -s "$tmpout" ]] && (( VERBOSE == 1 )); then
            printf "%bÇıktı:%b\n" "$RENK_MAVI" "$RENK_SIFIRLA"
            head -n 50 "$tmpout"
        fi
        
        ekran_ozeti "$komut_str" "$sure" "basarili"
        return 0
    else
        ilerleme_cubugu_durdur
        bitis=$(date +%s)
        sure=$((bitis - basla))
        
        kutu_yaz "$RENK_KIRMIZI" "✗ İşlem hata ile sonuçlandı"
        
        if [[ -s "$ERROR_LOG" ]]; then
            printf "%bHata detayları:%b\n" "$RENK_KIRMIZI" "$RENK_SIFIRLA"
            tail -n 30 "$ERROR_LOG"
        fi
        
        ekran_ozeti "$komut_str" "$sure" "hata"
        return 1
    fi
}


ERROR_LOG="$(mktemp_reg)" || exit 1

if [[ $# -eq 0 ]]; then
    yardim_goster
    exit 0
fi


while [[ $# -gt 0 ]]; do
    case "$1" in
        -e|--evet)
            OTOMATIK_ONAY=1
            shift
            ;;
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        -h|--yardim|yardim)
            yardim_goster
            exit 0
            ;;
        -V|--versiyon|versiyon)
            printf "TPK v%s\n" "$TPK_VERSION"
            exit 0
            ;;
        -*)
            printf "%bBilinmeyen seçenek: %s%b\n" "$RENK_KIRMIZI" "$1" "$RENK_SIFIRLA" >&2
            exit 1
            ;;
        *)
            break
            ;;
    esac
done


RAW_KOMUT="${1:-}"
shift || true

KOMUT="$(normalize_komut "$RAW_KOMUT")"


if ! yonetici="$(paket_yoneticisini_bul)"; then
    kutu_yaz "$RENK_KIRMIZI" "Hata: Desteklenen paket yöneticisi bulunamadı"
    exit 2
fi

logla "INFO" "Paket yöneticisi: $yonetici"


if [[ "$(id -u)" -ne 0 ]]; then
    USE_SUDO=1
    if ! command -v sudo &>/dev/null; then
        kutu_yaz "$RENK_KIRMIZI" "Hata: sudo komutu bulunamadı ve root değilsiniz"
        exit 2
    fi
fi


komut_dizisi=()
EKRAN_METNI=""


case "$KOMUT" in
    indir)
        if [[ $# -eq 0 ]]; then
            kutu_yaz "$RENK_KIRMIZI" "Hata: En az bir paket adı gerekli"
            exit 1
        fi
        
        EKRAN_METNI="Paket indiriliyor"
        
        if (( OTOMATIK_ONAY == 0 )); then
            if ! onay_iste "Paket(ler) kurulsun mu"; then
                kutu_yaz "$RENK_MAVI" "İşlem iptal edildi"
                exit 0
            fi
        fi
        
        case "$yonetici" in
            apt)
                komut_dizisi=(apt install -y "$@")
                ;;
            dnf|yum)
                komut_dizisi=("$yonetici" install -y "$@")
                ;;
            pacman)
                komut_dizisi=(pacman -S --noconfirm "$@")
                ;;
            zypper)
                komut_dizisi=(zypper install -y "$@")
                ;;
            apk)
                komut_dizisi=(apk add "$@")
                ;;
        esac
        
        komutu_calistir
        ;;
        
    kaldir|kaldır)
        if [[ $# -eq 0 ]]; then
            kutu_yaz "$RENK_KIRMIZI" "Hata: En az bir paket adı gerekli"
            exit 1
        fi
        
        EKRAN_METNI="Paket kaldırılıyor"
        
        if (( OTOMATIK_ONAY == 0 )); then
            if ! onay_iste "Paket(ler) kaldırılsın mı"; then
                kutu_yaz "$RENK_MAVI" "İşlem iptal edildi"
                exit 0
            fi
        fi
        
        case "$yonetici" in
            apt)
                komut_dizisi=(apt remove -y "$@")
                ;;
            dnf|yum)
                komut_dizisi=("$yonetici" remove -y "$@")
                ;;
            pacman)
                komut_dizisi=(pacman -Rns --noconfirm "$@")
                ;;
            zypper)
                komut_dizisi=(zypper remove -y "$@")
                ;;
            apk)
                komut_dizisi=(apk del "$@")
                ;;
        esac
        
        komutu_calistir
        ;;
        
    guncelle)
        case "$yonetici" in
            apt)
                komut_dizisi=(apt update)
                EKRAN_METNI="Paket listesi güncelleniyor"
                komutu_calistir
                ;;
            dnf|yum)
                komut_dizisi=("$yonetici" check-update)
                EKRAN_METNI="Güncellemeler kontrol ediliyor"
                komutu_calistir || true
                ;;
            pacman)
                komut_dizisi=(pacman -Sy --noconfirm)
                EKRAN_METNI="Veritabanı güncelleniyor"
                komutu_calistir
                ;;
            zypper)
                komut_dizisi=(zypper refresh)
                EKRAN_METNI="Depolar yenileniyor"
                komutu_calistir
                ;;
            apk)
                komut_dizisi=(apk update)
                EKRAN_METNI="Paket indeksi güncelleniyor"
                komutu_calistir
                ;;
        esac
        ;;
        
    ara)
        if [[ $# -eq 0 ]]; then
            kutu_yaz "$RENK_KIRMIZI" "Hata: Arama kelimesi gerekli"
            exit 1
        fi
        
        tmpout="$(mktemp_reg)" || exit 1
        
        case "$yonetici" in
            apt) komut_dizisi=(apt search "$@") ;;
            dnf|yum) komut_dizisi=("$yonetici" search "$@") ;;
            pacman) komut_dizisi=(pacman -Ss "$@") ;;
            zypper) komut_dizisi=(zypper search "$@") ;;
            apk) komut_dizisi=(apk search "$@") ;;
        esac
        
        printf "%bAranıyor: %s%b\n" "$RENK_MAVI" "$*" "$RENK_SIFIRLA"
        
        if "${komut_dizisi[@]}" >"$tmpout" 2>"$ERROR_LOG"; then
            kutu_yaz "$RENK_YESIL" "Arama sonuçları (ilk 30 satır)"
            head -n 30 "$tmpout"
            logla "INFO" "Arama: ${komut_dizisi[*]}"
        else
            kutu_yaz "$RENK_KIRMIZI" "Arama sırasında hata oluştu"
            [[ -s "$ERROR_LOG" ]] && tail -n 20 "$ERROR_LOG"
        fi
        ;;
        
    bilgi)
        if [[ $# -eq 0 ]]; then
            kutu_yaz "$RENK_KIRMIZI" "Hata: Paket adı gerekli"
            exit 1
        fi
        
        tmpout="$(mktemp_reg)" || exit 1
        
        case "$yonetici" in
            apt) komut_dizisi=(apt show "$@") ;;
            dnf|yum) komut_dizisi=("$yonetici" info "$@") ;;
            pacman) komut_dizisi=(pacman -Si "$@") ;;
            zypper) komut_dizisi=(zypper info "$@") ;;
            apk) komut_dizisi=(apk info -a "$@") ;;
        esac
        
        printf "%bPaket bilgisi alınıyor: %s%b\n" "$RENK_MAVI" "$*" "$RENK_SIFIRLA"
        
        if "${komut_dizisi[@]}" >"$tmpout" 2>"$ERROR_LOG"; then
            kutu_yaz "$RENK_YESIL" "Paket Bilgisi"
            cat "$tmpout"
            logla "INFO" "Bilgi: ${komut_dizisi[*]}"
        else
            kutu_yaz "$RENK_KIRMIZI" "Bilgi alınırken hata oluştu"
            [[ -s "$ERROR_LOG" ]] && tail -n 20 "$ERROR_LOG"
        fi
        ;;
        
    liste)
        tmpout="$(mktemp_reg)" || exit 1
        
        case "$yonetici" in
            apt) komut_dizisi=(apt list --installed) ;;
            dnf|yum) komut_dizisi=("$yonetici" list installed) ;;
            pacman) komut_dizisi=(pacman -Q) ;;
            zypper) komut_dizisi=(zypper se --installed-only) ;;
            apk) komut_dizisi=(apk info) ;;
        esac
        
        printf "%bKurulu paketler listeleniyor...%b\n" "$RENK_MAVI" "$RENK_SIFIRLA"
        
        if "${komut_dizisi[@]}" >"$tmpout" 2>"$ERROR_LOG"; then
            paket_sayisi=$(wc -l < "$tmpout")
            kutu_yaz "$RENK_YESIL" "Toplam kurulu paket: $paket_sayisi"
            head -n 100 "$tmpout"
            
            if [[ $paket_sayisi -gt 100 ]]; then
                printf "\n%b... ve %d paket daha%b\n" "$RENK_GRI" "$((paket_sayisi - 100))" "$RENK_SIFIRLA"
            fi
            
            logla "INFO" "Liste: ${komut_dizisi[*]}"
        else
            kutu_yaz "$RENK_KIRMIZI" "Listeleme sırasında hata oluştu"
            [[ -s "$ERROR_LOG" ]] && tail -n 20 "$ERROR_LOG"
        fi
        ;;
        
    temizle)
        case "$yonetici" in
            apt)
                komut_dizisi=(apt autoremove -y)
                EKRAN_METNI="Gereksiz paketler temizleniyor"
                komutu_calistir || true
                
                komut_dizisi=(apt autoclean)
                EKRAN_METNI="Önbellek temizleniyor"
                komutu_calistir || true
                ;;
            dnf|yum)
                komut_dizisi=("$yonetici" clean all)
                EKRAN_METNI="Önbellek temizleniyor"
                komutu_calistir
                ;;
            pacman)
                komut_dizisi=(pacman -Sc --noconfirm)
                EKRAN_METNI="Önbellek temizleniyor"
                komutu_calistir
                ;;
            zypper)
                komut_dizisi=(zypper clean -a)
                EKRAN_METNI="Tüm önbellekler temizleniyor"
                komutu_calistir
                ;;
            apk)
                komut_dizisi=(apk cache clean)
                EKRAN_METNI="Önbellek temizleniyor"
                komutu_calistir
                ;;
        esac
        ;;
        
    yardim|--help)
        yardim_goster
        ;;
        
    versiyon|--version)
        printf "TPK v%s\n" "$TPK_VERSION"
        printf "Bash: %s\n" "$BASH_VERSION"
        printf "Paket yöneticisi: %s\n" "$yonetici"
        ;;
        
    *)
        kutu_yaz "$RENK_KIRMIZI" "Bilinmeyen komut: $RAW_KOMUT"
        printf "\n%bYardım için: tpk yardim%b\n" "$RENK_MAVI" "$RENK_SIFIRLA"
        exit 1
        ;;
esac

exit 0
