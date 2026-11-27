#!/usr/bin/env python3
"""Generate DBML (dbdiagram.io) and Crow's-Foot SVG ER diagrams from T-SQL DDL."""

from __future__ import annotations

import html
import os
import re
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field


@dataclass
class ColumnDef:
    name: str
    dtype: str
    is_pk: bool = False
    is_fk: bool = False
    is_nn: bool = False
    is_uq: bool = False
    is_identity: bool = False


@dataclass
class TableDef:
    schema: str
    name: str
    columns: list[ColumnDef] = field(default_factory=list)
    pk_cols: set[str] = field(default_factory=set)
    uq_cols: set[str] = field(default_factory=set)
    fks: list[tuple[str, str, str]] = field(default_factory=list)  # (col, ref_table, ref_col)


def strip_comments(sql: str) -> str:
    sql = re.sub(r"/\*.*?\*/", " ", sql, flags=re.S)
    sql = re.sub(r"--[^\r\n]*", "", sql)
    return sql


def clean_ident(ident: str) -> str:
    return ident.strip().strip("[]")


def split_top_level(body: str) -> list[str]:
    items: list[str] = []
    cur: list[str] = []
    depth = 0
    in_str = False
    i = 0
    while i < len(body):
        ch = body[i]
        if in_str:
            cur.append(ch)
            if ch == "'":
                if i + 1 < len(body) and body[i + 1] == "'":
                    cur.append("'")
                    i += 2
                    continue
                in_str = False
        else:
            if ch == "'":
                in_str = True
                cur.append(ch)
            elif ch == "(":
                depth += 1
                cur.append(ch)
            elif ch == ")":
                depth -= 1
                cur.append(ch)
            elif ch == "," and depth == 0:
                items.append("".join(cur).strip())
                cur = []
                i += 1
                continue
            else:
                cur.append(ch)
        i += 1
    if cur and "".join(cur).strip():
        items.append("".join(cur).strip())
    return items


def parse_ddl(paths: list[str]) -> dict[str, TableDef]:
    tables: dict[str, TableDef] = {}

    for path in paths:
        raw = open(path, encoding="utf-8").read()
        sql = strip_comments(raw)

        for m in re.finditer(r"CREATE\s+TABLE\s+([a-zA-Z0-9_.\[\]]+)\s*\(", sql, re.I):
            full_name = clean_ident(m.group(1))
            if "." in full_name:
                schema, tname = [clean_ident(p) for p in full_name.split(".", 1)]
            else:
                schema, tname = "dbo", full_name

            start = m.end()
            depth = 1
            i = start
            in_str = False
            while i < len(sql) and depth > 0:
                ch = sql[i]
                if in_str:
                    if ch == "'":
                        if i + 1 < len(sql) and sql[i + 1] == "'":
                            i += 2
                            continue
                        in_str = False
                else:
                    if ch == "'":
                        in_str = True
                    elif ch == "(":
                        depth += 1
                    elif ch == ")":
                        depth -= 1
                i += 1

            body = sql[start : i - 1]
            tdef = TableDef(schema=schema, name=tname)

            for item in split_top_level(body):
                up = item.strip()
                if not up:
                    continue
                if re.match(r"^(CONSTRAINT|PRIMARY\s+KEY|FOREIGN\s+KEY|UNIQUE|CHECK)\b", up, re.I):
                    pk_m = re.search(r"PRIMARY\s+KEY\s*(?:CLUSTERED|NONCLUSTERED)?\s*\(([^)]+)\)", up, re.I)
                    if pk_m:
                        for c in pk_m.group(1).split(","):
                            tdef.pk_cols.add(clean_ident(c).split()[0])
                    uq_m = re.search(r"\bUNIQUE\s*(?:CLUSTERED|NONCLUSTERED)?\s*\(([^)]+)\)", up, re.I)
                    if uq_m:
                        cols = [clean_ident(c).split()[0] for c in uq_m.group(1).split(",")]
                        if len(cols) == 1:
                            tdef.uq_cols.add(cols[0])
                    fk_m = re.search(
                        r"FOREIGN\s+KEY\s*\(([^)]+)\)\s*REFERENCES\s+([a-zA-Z0-9_.\[\]]+)\s*\(([^)]+)\)",
                        up,
                        re.I,
                    )
                    if fk_m:
                        src_col = clean_ident(fk_m.group(1))
                        ref_tbl = ".".join(clean_ident(p) for p in fk_m.group(2).split("."))
                        ref_col = clean_ident(fk_m.group(3))
                        tdef.fks.append((src_col, ref_tbl, ref_col))
                    continue

                col_m = re.match(r"^(\[?[a-zA-Z0-9_]+\]?)\s+(.+)$", up, re.S)
                if not col_m:
                    continue
                cname = clean_ident(col_m.group(1))
                rest = " ".join(col_m.group(2).split())

                dt_m = re.match(
                    r"^([A-Za-z]+(?:\s*\(\s*(?:MAX|\d+(?:\s*,\s*\d+)?)\s*\))?)",
                    rest,
                    re.I,
                )
                dtype = dt_m.group(1).upper().replace(" ", "") if dt_m else rest.split()[0].upper()
                if "(" in dtype:
                    dtype = dtype.replace(",", ", ")

                is_pk = bool(re.search(r"\bPRIMARY\s+KEY\b", rest, re.I))
                is_nn = bool(re.search(r"\bNOT\s+NULL\b", rest, re.I)) or is_pk
                is_uq = bool(re.search(r"\bUNIQUE\b", rest, re.I))
                is_identity = bool(re.search(r"\bIDENTITY\s*\(", rest, re.I))
                is_fk = bool(re.search(r"\bREFERENCES\b", rest, re.I))

                if is_pk:
                    tdef.pk_cols.add(cname)
                if is_uq:
                    tdef.uq_cols.add(cname)
                if is_fk:
                    ref_m = re.search(r"REFERENCES\s+([a-zA-Z0-9_.\[\]]+)\s*\(([^)]+)\)", rest, re.I)
                    if ref_m:
                        ref_tbl = ".".join(clean_ident(p) for p in ref_m.group(1).split("."))
                        ref_col = clean_ident(ref_m.group(2))
                        tdef.fks.append((cname, ref_tbl, ref_col))

                tdef.columns.append(
                    ColumnDef(
                        name=cname,
                        dtype=dtype,
                        is_pk=is_pk,
                        is_fk=is_fk,
                        is_nn=is_nn,
                        is_uq=is_uq,
                        is_identity=is_identity,
                    )
                )

            tables[f"{schema}.{tname}"] = tdef

        for am in re.finditer(
            r"ALTER\s+TABLE\s+([a-zA-Z0-9_.\[\]]+)\s+ADD\s+(?:CONSTRAINT\s+[a-zA-Z0-9_\[\]]+\s+)?FOREIGN\s+KEY\s*\(([^)]+)\)\s*REFERENCES\s+([a-zA-Z0-9_.\[\]]+)\s*\(([^)]+)\)",
            sql,
            re.I | re.S,
        ):
            tbl_key = ".".join(clean_ident(p) for p in am.group(1).split("."))
            src_col = clean_ident(am.group(2))
            ref_tbl = ".".join(clean_ident(p) for p in am.group(3).split("."))
            ref_col = clean_ident(am.group(4))
            if tbl_key in tables:
                tables[tbl_key].fks.append((src_col, ref_tbl, ref_col))

    for tdef in tables.values():
        fk_cols = {fk[0] for fk in tdef.fks}
        for col in tdef.columns:
            if col.name in tdef.pk_cols:
                col.is_pk = True
                col.is_nn = True
            if col.name in fk_cols:
                col.is_fk = True
            if col.name in tdef.uq_cols:
                col.is_uq = True

    return tables


def generate_dbml(tables: dict[str, TableDef], out_path: str) -> None:
    lines: list[str] = [
        "// Auto-generated from schema/03..05 via scripts/generate_erd.py",
        "// Compatible with https://dbdiagram.io",
        "",
        "Project mini_snapp {",
        "  database_type: 'SQL Server'",
        "  Note: 'Multi-domain super-app database (core, taxi, food)'",
        "}",
        "",
    ]

    refs: list[str] = []
    seen_refs: set[str] = set()

    for key, t in tables.items():
        lines.append(f"Table {key} {{")
        for col in t.columns:
            settings: list[str] = []
            if col.is_pk:
                settings.append("pk")
            if col.is_identity:
                settings.append("increment")
            if col.is_nn and not col.is_pk:
                settings.append("not null")
            if col.is_uq:
                settings.append("unique")
            # DBML types cannot contain spaces/commas unquoted if composite; normalize spaces
            dbml_type = col.dtype.replace(", ", ",")
            suffix = f" [{', '.join(settings)}]" if settings else ""
            lines.append(f"  {col.name} {dbml_type}{suffix}")
        lines.append("}")
        lines.append("")

        for src_col, ref_tbl, ref_col in t.fks:
            ref_str = f"Ref: {key}.{src_col} > {ref_tbl}.{ref_col}"
            if ref_str not in seen_refs:
                seen_refs.add(ref_str)
                refs.append(ref_str)

    lines.append("// Foreign Key Relationships")
    lines.extend(refs)
    lines.append("")

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


def topological_order(schema_tables: list[TableDef]) -> list[TableDef]:
    by_key = {f"{t.schema}.{t.name}": t for t in schema_tables}
    memo: dict[str, int] = {}

    def depth(key: str, visiting: set[str]) -> int:
        if key in memo:
            return memo[key]
        if key in visiting:
            return 0
        visiting.add(key)
        t = by_key[key]
        parents = [
            fk[1]
            for fk in t.fks
            if fk[1] in by_key and fk[1] != key
        ]
        d = 0 if not parents else 1 + max(depth(p, visiting) for p in parents)
        visiting.remove(key)
        memo[key] = d
        return d

    orig_idx = {f"{t.schema}.{t.name}": i for i, t in enumerate(schema_tables)}
    return sorted(
        schema_tables,
        key=lambda t: (depth(f"{t.schema}.{t.name}", set()), orig_idx[f"{t.schema}.{t.name}"]),
    )


def orthogonal_rounded_path(points: list[tuple[float, float]], radius: float = 5.0) -> str:
    # Deduplicate consecutive identical points and collinear intermediates
    cleaned: list[tuple[float, float]] = []
    for pt in points:
        if not cleaned or cleaned[-1] != pt:
            cleaned.append(pt)

    simplified: list[tuple[float, float]] = []
    for pt in cleaned:
        while len(simplified) >= 2:
            x0, y0 = simplified[-2]
            x1, y1 = simplified[-1]
            x2, y2 = pt
            if (x0 == x1 == x2) or (y0 == y1 == y2):
                simplified.pop()
            else:
                break
        simplified.append(pt)

    if len(simplified) < 2:
        return ""
    if len(simplified) == 2:
        (x0, y0), (x1, y1) = simplified
        return f"M {x0:.1f} {y0:.1f} L {x1:.1f} {y1:.1f}"

    d_parts = [f"M {simplified[0][0]:.1f} {simplified[0][1]:.1f}"]
    for i in range(1, len(simplified) - 1):
        px, py = simplified[i - 1]
        cx, cy = simplified[i]
        nx, ny = simplified[i + 1]

        v1x, v1y = cx - px, cy - py
        v2x, v2y = nx - cx, ny - cy
        len1 = (v1x * v1x + v1y * v1y) ** 0.5
        len2 = (v2x * v2x + v2y * v2y) ** 0.5
        r = min(radius, len1 / 2.0, len2 / 2.0)

        if r <= 0.5:
            d_parts.append(f"L {cx:.1f} {cy:.1f}")
            continue

        ax = cx - (v1x / len1) * r
        ay = cy - (v1y / len1) * r
        bx = cx + (v2x / len2) * r
        by = cy + (v2y / len2) * r
        d_parts.append(f"L {ax:.1f} {ay:.1f} Q {cx:.1f} {cy:.1f} {bx:.1f} {by:.1f}")

    d_parts.append(f"L {simplified[-1][0]:.1f} {simplified[-1][1]:.1f}")
    return " ".join(d_parts)


SCHEMA_PALETTES = {
    "core": {"header": "#1e3a5f", "pk_bg": "#dbeafe", "pk_fg": "#1e40af", "fk_bg": "#e2e8f0", "fk_fg": "#334155"},
    "taxi": {"header": "#14532d", "pk_bg": "#dcfce7", "pk_fg": "#166534", "fk_bg": "#e2e8f0", "fk_fg": "#334155"},
    "food": {"header": "#7c2d12", "pk_bg": "#ffedd5", "pk_fg": "#9a3412", "fk_bg": "#e2e8f0", "fk_fg": "#334155"},
}


def render_schema_svg(
    schema: str,
    tables: dict[str, TableDef],
    out_path: str,
    title: str,
    subtitle: str,
) -> None:
    raw_tables = [t for t in tables.values() if t.schema == schema]
    ordered = topological_order(raw_tables)
    palette = SCHEMA_PALETTES[schema]

    cols_grid = 4
    card_w = 380
    header_h = 34
    row_h = 22
    pad_bottom = 8
    gap_x = 68
    gap_y = 54
    margin_x = 46
    top_banner = 86

    grid_rows: list[list[TableDef]] = [
        ordered[i : i + cols_grid] for i in range(0, len(ordered), cols_grid)
    ]

    # Store (x, y, w, h, row_idx, col_idx)
    card_boxes: dict[str, tuple[int, int, int, int, int, int]] = {}
    row_bottoms: list[int] = []
    cur_y = top_banner

    for r_idx, row_tables in enumerate(grid_rows):
        max_h = 0
        for c_idx, t in enumerate(row_tables):
            h = header_h + len(t.columns) * row_h + pad_bottom
            x = margin_x + c_idx * (card_w + gap_x)
            card_boxes[f"{t.schema}.{t.name}"] = (x, cur_y, card_w, h, r_idx, c_idx)
            if h > max_h:
                max_h = h
        row_bottoms.append(cur_y + max_h)
        cur_y += max_h + gap_y

    total_w = margin_x * 2 + cols_grid * card_w + (cols_grid - 1) * gap_x
    total_h = cur_y + 12

    # Build orthogonal edge paths strictly in whitespace gutters
    edge_paths: list[str] = []
    edge_idx = 0
    seen_edges: set[tuple[str, str, str, str]] = set()

    for t in ordered:
        src_key = f"{t.schema}.{t.name}"
        sx, sy, sw, sh, sr, sc = card_boxes[src_key]
        src_col_idx = {c.name: idx for idx, c in enumerate(t.columns)}

        for src_col, ref_tbl, ref_col in t.fks:
            if ref_tbl not in card_boxes or ref_tbl == src_key:
                continue
            ekey = (src_key, src_col, ref_tbl, ref_col)
            if ekey in seen_edges:
                continue
            seen_edges.add(ekey)

            rx, ry, rw, rh, dr, dc = card_boxes[ref_tbl]
            dst_t = tables[ref_tbl]
            dst_col_idx = {c.name: idx for idx, c in enumerate(dst_t.columns)}

            src_y = sy + header_h + src_col_idx.get(src_col, 0) * row_h + row_h / 2.0
            if ref_col in dst_col_idx:
                dst_y = ry + header_h + dst_col_idx[ref_col] * row_h + row_h / 2.0
            else:
                dst_y = ry + header_h / 2.0

            lane_v = ((edge_idx % 5) - 2) * 5.0
            lane_h = ((edge_idx % 5) - 2) * 5.0
            edge_idx += 1

            # Choose side attachment & gutter X
            if sc < dc:
                start_x = sx + sw
                gx1 = sx + sw + gap_x / 2.0 + lane_v
                end_x = rx
                gx2 = rx - gap_x / 2.0 + lane_v
            elif sc > dc:
                start_x = sx
                gx1 = sx - gap_x / 2.0 + lane_v
                end_x = rx + rw
                gx2 = rx + rw + gap_x / 2.0 + lane_v
            else:
                # Same grid column: exit right side into right gutter
                start_x = sx + sw
                end_x = rx + rw
                gx1 = sx + sw + (gap_x / 2.0 if sc < cols_grid - 1 else margin_x / 2.0) + lane_v
                gx2 = gx1

            if sr == dr and abs(sc - dc) == 1:
                # Directly adjacent horizontal cards in same row
                pts = [(start_x, src_y), (gx1, src_y), (gx1, dst_y), (end_x, dst_y)]
            else:
                # Pick horizontal gutter strictly between rows (below lower-indexed row)
                if dr < sr:
                    gy = row_bottoms[sr - 1] + gap_y / 2.0 + lane_h
                elif dr > sr:
                    gy = row_bottoms[sr] + gap_y / 2.0 + lane_h
                else:
                    # Same row, non-adjacent columns -> route along gutter below this row
                    gy = row_bottoms[sr] + gap_y / 2.0 + lane_h
                pts = [
                    (start_x, src_y),
                    (gx1, src_y),
                    (gx1, gy),
                    (gx2, gy),
                    (gx2, dst_y),
                    (end_x, dst_y),
                ]

            d = orthogonal_rounded_path(pts, radius=5.0)
            if d:
                edge_paths.append(
                    f'    <path d="{d}" marker-start="url(#crow-many)" marker-end="url(#one-only)" />'
                )

    svg: list[str] = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{total_w}" height="{total_h}" viewBox="0 0 {total_w} {total_h}" font-family="ui-sans-serif, -apple-system, BlinkMacSystemFont, \'Segoe UI\', Helvetica, Arial, sans-serif">',
        "  <defs>",
        '    <marker id="one-only" viewBox="0 0 12 12" refX="11" refY="6" markerWidth="10" markerHeight="10" orient="auto">',
        '      <path d="M 4 2 L 4 10 M 8 2 L 8 10" stroke="#64748b" stroke-width="1.5" fill="none" />',
        "    </marker>",
        '    <marker id="crow-many" viewBox="0 0 12 12" refX="0" refY="6" markerWidth="10" markerHeight="10" orient="auto">',
        '      <path d="M 0 2 L 10 6 M 0 6 L 10 6 M 0 10 L 10 6" stroke="#64748b" stroke-width="1.35" fill="none" />',
        "    </marker>",
        "  </defs>",
        f'  <rect width="{total_w}" height="{total_h}" fill="#f8fafc" rx="10" />',
        f'  <text x="{margin_x}" y="36" font-size="22" font-weight="700" fill="#0f172a">{html.escape(title)}</text>',
        f'  <text x="{margin_x}" y="58" font-size="13" fill="#475569">{html.escape(subtitle)} | Crow\'s-Foot Notation (Auto-generated from DDL)</text>',
        '  <g id="relationships" fill="none" stroke="#64748b" stroke-width="1.35" stroke-opacity="0.72">',
        *edge_paths,
        "  </g>",
        '  <g id="tables">',
    ]

    for t in ordered:
        x, y, w, h, _, _ = card_boxes[f"{t.schema}.{t.name}"]
        svg.append(
            f'    <rect x="{x}" y="{y}" width="{w}" height="{h}" rx="7" fill="#ffffff" stroke="#cbd5e1" stroke-width="1.25" />'
        )
        svg.append(
            f'    <path d="M {x} {y+7} Q {x} {y} {x+7} {y} L {x+w-7} {y} Q {x+w} {y} {x+w} {y+7} L {x+w} {y+header_h} L {x} {y+header_h} Z" fill="{palette["header"]}" />'
        )
        svg.append(
            f'    <text x="{x + 12}" y="{y + 22}" font-size="13.5" font-weight="700" fill="#ffffff">{html.escape(t.schema + "." + t.name)}</text>'
        )

        ext_schemas = sorted({fk[1].split(".")[0] for fk in t.fks if not fk[1].startswith(schema + ".")})
        if ext_schemas:
            ext_label = "refs: " + ", ".join(ext_schemas)
            svg.append(
                f'    <text x="{x + w - 10}" y="{y + 21}" font-size="10.5" font-weight="600" fill="#cbd5e1" text-anchor="end">{html.escape(ext_label)}</text>'
            )

        for idx, col in enumerate(t.columns):
            ry = y + header_h + idx * row_h
            if idx % 2 == 1:
                svg.append(
                    f'    <rect x="{x + 1}" y="{ry}" width="{w - 2}" height="{row_h}" fill="#f8fafc" />'
                )

            badge_x = x + 10
            if col.is_pk or col.is_fk:
                tag = "PK,FK" if (col.is_pk and col.is_fk) else ("PK" if col.is_pk else "FK")
                bg = palette["pk_bg"] if col.is_pk else palette["fk_bg"]
                fg = palette["pk_fg"] if col.is_pk else palette["fk_fg"]
                bw = 36 if tag == "PK,FK" else 24
                svg.append(
                    f'    <rect x="{badge_x}" y="{ry + 4}" width="{bw}" height="14" rx="3" fill="{bg}" />'
                )
                svg.append(
                    f'    <text x="{badge_x + bw / 2.0}" y="{ry + 14}" font-size="9" font-weight="700" fill="{fg}" text-anchor="middle">{tag}</text>'
                )
                name_x = badge_x + bw + 6
            else:
                name_x = x + 12

            col_color = "#0f172a" if (col.is_pk or col.is_fk) else "#334155"
            col_weight = "700" if col.is_pk else ("600" if col.is_fk else "400")
            svg.append(
                f'    <text x="{name_x}" y="{ry + 15}" font-size="11.5" font-weight="{col_weight}" fill="{col_color}">{html.escape(col.name)}</text>'
            )

            flags = []
            if col.is_uq:
                flags.append("UQ")
            if col.is_nn and not col.is_pk:
                flags.append("NN")
            flag_str = f" [{','.join(flags)}]" if flags else ""
            right_label = f"{col.dtype}{flag_str}"
            svg.append(
                f'    <text x="{x + w - 10}" y="{ry + 15}" font-size="10" font-family="ui-monospace, SFMono-Regular, Menlo, monospace" fill="#64748b" text-anchor="end">{html.escape(right_label)}</text>'
            )

    svg.append("  </g>")
    svg.append("</svg>\n")

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(svg))
    ET.parse(out_path)


def main() -> None:
    repo = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    ddl_files = [
        os.path.join(repo, "schema/03_core_table_v1.sql"),
        os.path.join(repo, "schema/04_taxi_table_v1.sql"),
        os.path.join(repo, "schema/05_food_tables_v1.sql"),
    ]
    tables = parse_ddl(ddl_files)
    counts = {s: sum(1 for t in tables.values() if t.schema == s) for s in ("core", "taxi", "food")}
    assert counts == {"core": 15, "taxi": 13, "food": 18}, f"Unexpected table counts: {counts}"

    dbml_path = os.path.join(repo, "docs/er_diagrams/mini_snapp.dbml")
    generate_dbml(tables, dbml_path)

    render_schema_svg(
        "core",
        tables,
        os.path.join(repo, "docs/er_diagrams/core/core_schema_erd.svg"),
        "Core Schema Physical ERD",
        "15 tables | Identity, RBAC, Wallets, Transactions, Coupons, Addresses, Complaints & Logs",
    )
    render_schema_svg(
        "taxi",
        tables,
        os.path.join(repo, "docs/er_diagrams/taxi/taxi_schema_erd.svg"),
        "Taxi Schema Physical ERD",
        "13 tables | Drivers, Vehicles, Live Locations, Pricing Parameters, Offers & Rides",
    )
    render_schema_svg(
        "food",
        tables,
        os.path.join(repo, "docs/er_diagrams/food/food_schema_erd.svg"),
        "Food Schema Physical ERD",
        "18 tables | Brands, Branches, Schedules, Ingredients, Menus, Carts, Orders & Wallets",
    )
    print(f"Generated {dbml_path} and 3 Crow's-Foot SVG diagrams ({sum(counts.values())} tables total).")


if __name__ == "__main__":
    main()
