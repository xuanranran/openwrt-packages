#!/bin/sh

PATH="/usr/sbin:/usr/bin:/sbin:/bin"

checkmd5(){
	local nowmd5
	nowmd5="$(md5sum /tmp/adguard.list 2>/dev/null)"
	nowmd5="${nowmd5%% *}"
	local lastmd5
	lastmd5="$(uci get AdGuardHome.AdGuardHome.gfwlistmd5 2>/dev/null)"
	if [ "$nowmd5" != "$lastmd5" ]; then
		uci set AdGuardHome.AdGuardHome.gfwlistmd5="$nowmd5"
		uci commit AdGuardHome
		[ "$1" != "noreload" ] && /etc/init.d/AdGuardHome reload >/dev/null 2>&1
	fi
}

configpath="$(uci get AdGuardHome.AdGuardHome.configpath 2>/dev/null)"
if [ -z "$configpath" ]; then
	configpath="/etc/AdGuardHome.yaml"
fi

if [ "$1" = "del" ]; then
	sed -i '/programaddstart/,/programaddend/d' "$configpath"
	checkmd5 "$2"
	exit 0
fi

gfwupstream="$(uci get AdGuardHome.AdGuardHome.gfwupstream 2>/dev/null)"
if [ -z "$gfwupstream" ]; then
	gfwupstream="tcp://208.67.220.220:5353"
fi

if [ ! -f "$configpath" ]; then
	echo "错误：配置文件未找到，请先创建配置"
	exit 1
fi

echo "正在下载 gfwlist..."
GFWLIST_URL="https://gitlab.com/gfwlist/gfwlist/raw/master/gfwlist.txt"
if curl -sL -k --retry 2 --connect-timeout 20 -o /tmp/gfwlist.txt "$GFWLIST_URL" 2>/dev/null; then
	:
elif wget-ssl --no-check-certificate -t 2 -T 20 -O /tmp/gfwlist.txt "$GFWLIST_URL" 2>/dev/null; then
	:
else
	echo "错误：gfwlist 下载失败"
	exit 1
fi

if [ ! -s /tmp/gfwlist.txt ]; then
	echo "错误：gfwlist 下载内容为空"
	rm -f /tmp/gfwlist.txt
	exit 1
fi

# Decode base64. Prefer system tools, fall back to embedded lua decoder
# because OpenWrt/ImmortalWrt minimal builds often lack base64 / openssl CLIs.
decode_b64() {
	if command -v base64 >/dev/null 2>&1; then
		base64 -d < "$1" > "$2" 2>/dev/null && return 0
	fi
	if command -v openssl >/dev/null 2>&1; then
		openssl base64 -d -A < "$1" > "$2" 2>/dev/null && return 0
	fi
	if command -v lua >/dev/null 2>&1; then
		lua - "$1" "$2" <<'LUAEOF'
local f = assert(io.open(arg[1], "rb"))
local data = f:read("*a"):gsub("%s+", "")
f:close()
local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local out, buf, bits = {}, 0, 0
for c in data:gmatch(".") do
	if c == "=" then break end
	local i = b:find(c, 1, true)
	if i then
		buf = buf * 64 + (i - 1)
		bits = bits + 6
		if bits >= 8 then
			bits = bits - 8
			local div = 2 ^ bits
			out[#out + 1] = string.char(math.floor(buf / div))
			buf = buf % div
		end
	end
end
local o = assert(io.open(arg[2], "wb"))
o:write(table.concat(out))
o:close()
LUAEOF
		[ -s "$2" ] && return 0
	fi
	return 1
}

decode_b64 /tmp/gfwlist.txt /tmp/gfwlist_decoded.txt
if [ $? -ne 0 ] || [ ! -s /tmp/gfwlist_decoded.txt ]; then
	echo "错误：gfwlist 解码失败 (系统需要 base64 / openssl / lua 之一)"
	rm -f /tmp/gfwlist.txt
	exit 1
fi

awk -v upst="$gfwupstream" '
BEGIN {
	getline
}
{
	s1 = substr($0, 1, 1)
	if (s1 == "!") next
	white = 0
	if (s1 == "@") {
		$0 = substr($0, 3)
		s1 = substr($0, 1, 1)
		white = 1
	}

	if (s1 == "|") {
		s2 = substr($0, 2, 1)
		if (s2 == "|") {
			$0 = substr($0, 3)
			n = split($0, d, "/")
			$0 = d[1]
		} else {
			n = split($0, d, "/")
			$0 = d[3]
		}
	} else {
		n = split($0, d, "/")
		$0 = d[1]
	}

	star = index($0, "*")
	if (star != 0) {
		$0 = substr($0, star + 1)
		dot = index($0, ".")
		if (dot != 0)
			$0 = substr($0, dot + 1)
		else
			next
		s1 = substr($0, 1, 1)
	}

	if (s1 == ".")
		fin = substr($0, 2)
	else
		fin = $0

	if (index(fin, ".") == 0) next
	if (index(fin, "%") != 0) next
	if (index(fin, ":") != 0) next

	if (match(fin, "^[0-9.]+$")) next
	if (fin == "" || fin == finl) next
	finl = fin

	if (white == 0)
		print "    - \"[/." fin "/]" upst "\""
	else
		print "    - \"[/." fin "/]#\""
}
END {
	print "    - \"[/programaddend/]#\""
}' /tmp/gfwlist_decoded.txt > /tmp/adguard.list

rm -f /tmp/gfwlist.txt /tmp/gfwlist_decoded.txt

# 总是先清除旧区段，再插入新区段（确保幂等）
sed -i '/programaddstart/,/programaddend/d' "$configpath"
sed -i '1i\    - "[/programaddstart/]#"' /tmp/adguard.list
# AGH yaml: upstream_dns 在 dns: 下，带 2 空格缩进；兼容老版顶层格式
sed -i '/^[[:space:]]*upstream_dns:[[:space:]]*$/r /tmp/adguard.list' "$configpath"

checkmd5 "$2"
rm -f /tmp/adguard.list
