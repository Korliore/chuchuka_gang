#!/bin/sh

OUTLINE_KEY=$1

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# реклама, ну а чо)
qr_code() {
    echo "
  ██████████████  ██████      ██████████████
  ██          ██  ██  ██      ██          ██
  ██  ██████  ██    ████  ██  ██  ██████  ██
  ██  ██████  ██    ████      ██  ██████  ██
  ██  ██████  ██  ████████    ██  ██████  ██
  ██          ██  ████  ██    ██          ██
  ██████████████  ██  ██  ██  ██████████████
                  ██    ████
  ██████    ████  ████████  ████████    ████
      ██████      ████    ██  ██  ██████  ██
    ████  ██  ████  ████  ██  ██  ████  ████
    ██  ██████  ████████    ██      ██
      ██████  ████  ██████        ████    ██
                  ██████  ██    ████████████
  ██████████████      ██  ██      ██  ██  ██
  ██          ██  ████████████  ██  ██  ██
  ██  ██████  ██    ██  ██████  ██  ██  ████
  ██  ██████  ██    ██    ██  ██  ████  ██
  ██  ██████  ██  ██      ██████  ██  ██████
  ██          ██  ██    ██  ██  ████
  ██████████████  ██████  ████      ██    ██
    "
    echo "Здесь про IT и не только. https://t.me/itishechka21"
}

# Функция для удаления установленных пакетов
remove_packages() {
    opkg --force-removal-of-dependent-packages remove shadowsocks-libev-ss-local shadowsocks-libev-ss-redir shadowsocks-libev-ss-rules shadowsocks-libev-ss-tunnel shadowsocks-libev-config luci-app-shadowsocks-libev
    opkg --force-removal-of-dependent-packages remove ss_checker
    opkg --force-removal-of-dependent-packages remove ruantiblock
    rm -rf /etc/config/shadowsocks-libev /etc/config/shadowsocks-libev-opkg /etc/config/ruantiblock /etc/config/ruantiblock-opkg
    echo -e "${RED}Роутер будет перезагружен. Пожалуйста, подождите.${NC}"
    sleep 2
    reboot
}

# Функция для установки пакетов
install() {
    # Обновляем пакеты и качаем shadowsocks
    opkg update
    opkg install shadowsocks-libev-ss-local shadowsocks-libev-ss-redir shadowsocks-libev-ss-rules shadowsocks-libev-ss-tunnel shadowsocks-libev-config
    opkg install luci-app-shadowsocks-libev

    # Ставим чекер
    wget --no-check-certificate -O /tmp/ss_checker_1.1.0-1_all.ipk https://github.com/gSpotx2f/packages-openwrt/raw/master/current/ss_checker_1.1.0-1_all.ipk
    opkg install /tmp/ss_checker_1.1.0-1_all.ipk
    rm /tmp/ss_checker_1.1.0-1_all.ipk

    # Проверка ключа
    output=$(ss_checker $OUTLINE_KEY 2>&1)
    if echo "$output" | grep -qE "Error!|FAILED|traceback"; then
        echo -e "${RED}Ошибка:${NC} Ключ не рабочий. Попробуйте другой ключ. Подробнее: $output"
        exit 1
    fi

    # Конфигурация shadowsocks
    ss_set_server.sh "$OUTLINE_KEY"

    # Установка антиблока, настроенного на прокси
    wget --no-check-certificate -O /tmp/autoinstall.sh https://raw.githubusercontent.com/gSpotx2f/ruantiblock_openwrt/master/autoinstall/current/autoinstall.sh && chmod +x /tmp/autoinstall.sh && printf '%s\n' 3 2 Y Y | /tmp/autoinstall.sh

    # Дополнительная настройка
    uci set ruantiblock.config.proxy_mode="3"
    uci set ruantiblock.config.t_proxy_port_tcp="1100"
    uci set ruantiblock.config.t_proxy_allow_udp="1"
    uci set ruantiblock.config.add_user_entries="1"
    uci set ruantiblock.config.user_entries_remote="https://raw.githubusercontent.com/Korliore/chuchuka_gang/refs/heads/main/custom_list"
    uci commit ruantiblock
    /usr/bin/ruantiblock update
    /etc/init.d/ruantiblock enable
    /usr/bin/ruantiblock start
    echo -e "${GREEN} Установка прошла успешно. Роутер будет перезагружен. Пожалуйста, подождите.${NC}"
    sleep 2
    reboot
}

# Проверка флага --remove
if [ "$OUTLINE_KEY" = "--remove" ]; then
    remove_packages
    exit 0
fi

# Проверка наличия OUTLINE_KEY
if [ -z "$OUTLINE_KEY" ]; then
    echo -e "${RED}Ошибка:${NC} Использование: ${YELLOW}$0 OUTLINE_KEY${NC}"
    echo -e "Для удаления обхода используйте: ${YELLOW}$0 --remove${NC}"
    exit 1
fi

# такая себе валидация, чтобы всякая дичь не попала
if [[ ! "$OUTLINE_KEY" == *"ss://"* || ! "$OUTLINE_KEY" == *"outline"* ]]; then
    echo -e "${RED}Ошибка:${NC} OUTLINE_KEY должен иметь вид "
    echo -e "${YELLOW}ss://Zm9vYmFybjAtYW5vdGhlcnI6c2VjdXJpdHk0Mzg4OmludGVydmF0aXZlWmFsdG9yYW50YWx1ZXM=@example.com:12345/?outline=1${NC}"
    exit 1
fi

qr_code
sleep 3
read -p "Хотите начать установку? (Y/N): " start_install
choice=$(echo "$start_install" | tr '[:upper:]' '[:lower:]')
if [[ "$choice" == "y" ]]; then
    install
else
    echo "Установка отменена."
fi
