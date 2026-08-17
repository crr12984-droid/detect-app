# -*- coding: utf-8 -*-
"""从 nmap-mac-prefixes（IEEE OUI 权威数据）生成准确的 OUI→品牌映射。
输出 lib/core/oui_map.dart，供 brand_db.dart 使用。仅保留能映射到已知品牌的 OUI，
避免引入无关厂商噪声，同时最大化覆盖（华为/苹果/三星/TP-Link/小米等自有 OUI 全部纳入）。
"""
import urllib.request
import re

URL = "https://gitlab.com/kalilinux/packages/nmap/-/raw/kali/master/nmap-mac-prefixes"

# 厂商名关键词 -> 品牌（按顺序匹配，先匹配更具体的）
RULES = [
    ("linksys", "Linksys"),
    ("cisco", "Cisco"),
    ("aruba", "Aruba"),
    ("hp ", "HP"),
    ("hpe", "HP"),
    ("hewlett", "HP"),
    ("h3c", "H3C"),
    ("ruijie", "Ruijie"),
    ("fiberhome", "Fiberhome"),
    ("huawei", "Huawei"),
    ("honor", "Honor"),
    ("xiaomi", "Xiaomi"),
    ("redmi", "Xiaomi"),
    ("oppo", "OPPO"),
    ("vivo", "vivo"),
    ("bbk", "OPPO"),
    ("oneplus", "OnePlus"),
    ("realme", "realme"),
    ("meizu", "Meizu"),
    ("zte", "ZTE"),
    ("tp-link", "TP-Link"),
    ("tplink", "TP-Link"),
    ("tp link", "TP-Link"),
    ("tenda", "Tenda"),
    ("mercury", "Mercury"),
    ("fast", "Fast"),
    ("mercusys", "Mercusys"),
    ("phicomm", "Phicomm"),
    ("totolink", "TOTOLINK"),
    ("edimax", "EDIMAX"),
    ("trendnet", "TRENDnet"),
    ("d-link", "D-Link"),
    ("netgear", "Netgear"),
    ("asus", "ASUS"),
    ("ubiqui", "Ubiquiti"),
    ("mikrotik", "MikroTik"),
    ("eero", "Eero"),
    ("zyxel", "Zyxel"),
    ("belkin", "Belkin"),
    ("buffalo", "Buffalo"),
    ("google", "Google"),
    ("nest", "Google"),
    ("samsung", "Samsung"),
    ("sony", "Sony"),
    ("lg ", "LG"),
    ("intel", "Intel"),
    ("qualcomm", "Qualcomm"),
    ("atheros", "Qualcomm"),
    ("broadcom", "Broadcom"),
    ("realtek", "Realtek"),
    ("mediatek", "MediaTek"),
    ("ralink", "MediaTek"),
    ("espressif", "Espressif"),
    ("nokia", "Nokia"),
    ("motorola", "Motorola"),
    ("lenovo", "Lenovo"),
    ("dell", "Dell"),
    ("microsoft", "Microsoft"),
    ("juniper", "Juniper"),
    ("amazon", "Amazon"),
    ("meta", "Meta"),
    ("nvidia", "NVIDIA"),
    ("tcl", "TCL"),
    ("hisense", "Hisense"),
    ("sagemcom", "Sagemcom"),
    ("technicolor", "Technicolor"),
    ("arris", "Arris"),
    ("sercomm", "Sercomm"),
    ("compal", "Compal"),
    ("foxconn", "Foxconn"),
    ("gemtek", "Gemtek"),
    ("arcadyan", "Arcadyan"),
    ("hitron", "Hitron"),
    ("ubee", "Ubee"),
    ("dareglobal", "DareGlobal"),
    ("casa", "Casa"),
    ("apple", "Apple"),
]

# 国产品牌集合（用于“国产/进口”标签）
DOMESTIC = {
    "Huawei", "Honor", "Xiaomi", "OPPO", "vivo", "OnePlus", "realme", "Meizu",
    "ZTE", "TP-Link", "Tenda", "Mercury", "Fast", "Mercusys", "Phicomm",
    "TOTOLINK", "EDIMAX", "TRENDnet", "Lenovo", "H3C", "Ruijie", "Fiberhome",
    "Zyxel", "TCL", "Hisense", "ChinaMobile", "ChinaTelecom", "ChinaUnicom",
    "Baidu", "Haier", "Gree", "Skyworth", "Konka", "JCG", "Youku",
}


def map_brand(vendor: str) -> str | None:
    v = vendor.lower()
    for kw, brand in RULES:
        if kw in v:
            return brand
    return None


def main():
    print("downloading...")
    data = urllib.request.urlopen(URL, timeout=60).read().decode("utf-8", "replace")
    out = {}
    for line in data.splitlines():
        line = line.strip()
        if not line or line.startswith("$") or line.startswith("#"):
            continue
        # 格式： "OUI<TAB>Vendor" 或 "OUI Space+ Vendor"
        parts = line.split(None, 1)
        if len(parts) < 2:
            continue
        oui = parts[0].upper().replace(":", "").replace("-", "")
        if len(oui) != 6 or not re.fullmatch(r"[0-9A-F]{6}", oui):
            continue
        brand = map_brand(parts[1])
        if brand is None:
            continue
        out[oui] = brand  # 后者覆盖前者（同 OUI 极少重复）

    # 写出 Dart 文件
    lines = [
        "// AUTO-GENERATED from nmap-mac-prefixes (IEEE OUI registry).",
        "// 由 gen_oui.py 生成，请勿手改。OUI 前缀(前3字节) -> 品牌。",
        "const Map<String, String> kOuiToBrand = {",
    ]
    for oui in sorted(out):
        lines.append("  '%s': '%s'," % (oui, out[oui]))
    lines.append("};")
    lines.append("")
    lines.append("const Set<String> kOuiDomestic = {")
    for b in sorted(DOMESTIC):
        lines.append("  '%s'," % b)
    lines.append("};")
    lines.append("")
    text = "\n".join(lines)
    path = "D:/代码开发/智能终端检测系统/detect_app/lib/core/oui_map.dart"
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    # 统计各品牌数量
    from collections import Counter
    c = Counter(out.values())
    print("TOTAL OUI entries:", len(out))
    print("BRANDS:", len(c))
    for b, n in c.most_common():
        print("  %-12s %d" % (b, n))


if __name__ == "__main__":
    main()
