#!/usr/bin/env bash
# Ham dung chung: kiem tra / giai phong cong cho dub_app.
# Source: source "$SCRIPT_DIR/scripts/port_utils.sh"

port_in_use() {
    local port="$1"
    if command -v ss &>/dev/null; then
        ss -tlnH 2>/dev/null | grep -qE ":${port}[[:space:]]"
        return $?
    fi
    if command -v fuser &>/dev/null; then
        fuser "${port}/tcp" &>/dev/null
        return $?
    fi
    return 1
}

ensure_port_free() {
    local port="$1"
    local script_dir="$2"

    if ! port_in_use "$port"; then
        return 0
    fi

    echo "[CANH BAO] Cong ${port} dang duoc su dung — dang giai phong instance cu..."

    pkill -f "${script_dir}/app.py" 2>/dev/null || true
    pkill -f "${script_dir}/run.sh" 2>/dev/null || true
    sleep 2

    if port_in_use "$port" && command -v fuser &>/dev/null; then
        fuser -k "${port}/tcp" 2>/dev/null || true
        sleep 1
    fi

    if port_in_use "$port"; then
        echo "[LOI] Cong ${port} van bi chiem."
        echo "      Thu: ./stop_all.sh"
        echo "      Hoac doi cong: GRADIO_PORT=8001 ./run.sh"
        return 1
    fi

    echo "[OK] Da giai phong cong ${port}."
    return 0
}
