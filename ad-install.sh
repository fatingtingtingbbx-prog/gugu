#!/bin/bash

# Copyright (c) 2025 清绝 (QingJue) <blog.qjyg.de>
# This script is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
# To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/
#
# 郑重声明：
# 本脚本为免费开源项目，仅供个人学习和非商业用途使用。
# 未经作者授权，严禁将本脚本或其修改版本用于任何形式的商业盈利行为（包括但不限于倒卖、付费部署服务等）。
# 任何违反本协议的行为都将受到法律追究。

SOURCE_MANIFEST_URL="https://gugu.qjyg.de/source-manifest.json"
SCRIPT_MANIFEST_KEY="ad_st"
FILENAME="ad-st.sh"
FALLBACK_SCRIPT_URL="https://cdn.jsdelivr.net/gh/qingjue723/gugu-st-tools@main/ad-st.sh"

fn_get_manifest_value() {
  local key="$1"
  local content value

  if ! content="$(curl -fsSL --connect-timeout 15 "${SOURCE_MANIFEST_URL}")"; then
    echo "哎呀，获取发布源清单失败了。检查下网络或者域名服务？" >&2
    exit 1
  fi

  value="$(printf '%s' "${content}" | tr -d '\r\n' | sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p")"
  if [ -z "${value}" ]; then
    echo "哎呀，发布源清单里缺少字段：${key}" >&2
    exit 1
  fi

  printf '%s' "${value}"
}

fn_validate_script() {
  local file="$1"
  local first_line
  first_line="$(head -c 20 "$file" 2>/dev/null)"
  case "$first_line" in
    \#!/*) return 0 ;;
    \#!*) return 0 ;;
    *) return 1 ;;
  esac
}

fn_download_script() {
  local url="$1"
  local out_file="$2"
  curl -fsSL --connect-timeout 15 -o "$out_file" "$url" 2>/dev/null
}

echo "正在准备下载最新版的 ${FILENAME} 脚本..."

SCRIPT_URL="$(fn_get_manifest_value "${SCRIPT_MANIFEST_KEY}")"
TEMP_FILE="$(mktemp 2>/dev/null || echo "/tmp/gugu_install_$$.sh")"

if fn_download_script "${SCRIPT_URL}" "${TEMP_FILE}" && fn_validate_script "${TEMP_FILE}"; then
  : # 主源下载成功
else
  echo "主源下载失败或内容异常，正在尝试备用源 (jsdelivr CDN)..." >&2
  rm -f "${TEMP_FILE}"
  if fn_download_script "${FALLBACK_SCRIPT_URL}" "${TEMP_FILE}" && fn_validate_script "${TEMP_FILE}"; then
    : # 备用源下载成功
  else
    rm -f "${TEMP_FILE}"
    cat >&2 <<'EOF'
哎呀，下载失败了。可能原因：
  1. 短链被限流（GitHub raw 访问过多），请稍后重试
  2. 当前网络无法访问 GitHub 相关服务

可手动执行的备用方案：
  curl -sSL https://cdn.jsdelivr.net/gh/qingjue723/gugu-st-tools@main/ad-install.sh | bash
EOF
    exit 1
  fi
fi

sed -i 's/\r$//' "${TEMP_FILE}" 2>/dev/null || true
mv "${TEMP_FILE}" "${FILENAME}"
chmod +x "${FILENAME}"

echo "脚本准备好了！马上运行..."
echo "------------------------------------"

./"${FILENAME}" "$@" < /dev/tty
