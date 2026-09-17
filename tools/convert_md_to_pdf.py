import os
import re
import subprocess
import html
import sys

EDGE_PATH = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

def markdown_to_html(md_text, title="Documento Institucional UDEC"):
    lines = md_text.splitlines()
    html_lines = []
    in_code_block = False
    code_lang = ""
    code_buffer = []
    in_table = False
    table_buffer = []

    def flush_table():
        nonlocal in_table, table_buffer
        if not table_buffer:
            return ""
        out = ["<table class='udec-table'>"]
        if len(table_buffer) >= 2:
            header_cells = [c.strip() for c in table_buffer[0].split('|')[1:-1]]
            out.append("<thead><tr>")
            for c in header_cells:
                out.append(f"<th>{process_inline(c)}</th>")
            out.append("</tr></thead>")
            out.append("<tbody>")
            for row in table_buffer[2:]:
                cells = [c.strip() for c in row.split('|')[1:-1]]
                out.append("<tr>")
                for c in cells:
                    out.append(f"<td>{process_inline(c)}</td>")
                out.append("</tr>")
            out.append("</tbody>")
        out.append("</table>")
        table_buffer = []
        in_table = False
        return "\n".join(out)

    def process_inline(text):
        text = html.escape(text)
        text = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', text)
        text = re.sub(r'\*(.+?)\*', r'<em>\1</em>', text)
        text = re.sub(r'`(.+?)`', r'<code>\1</code>', text)
        return text

    i = 0
    while i < len(lines):
        line = lines[i]

        if line.startswith("```"):
            if in_code_block:
                in_code_block = False
                code_content = html.escape("\n".join(code_buffer))
                html_lines.append(f"<pre class='code-block'><code>{code_content}</code></pre>")
                code_buffer = []
            else:
                if in_table:
                    html_lines.append(flush_table())
                in_code_block = True
                code_lang = line[3:].strip()
            i += 1
            continue

        if in_code_block:
            code_buffer.append(line)
            i += 1
            continue

        if "|" in line and (line.strip().startswith("|") or line.strip().endswith("|")):
            in_table = True
            table_buffer.append(line.strip())
            i += 1
            continue
        elif in_table:
            html_lines.append(flush_table())

        if line.strip() in ("---", "***", "___"):
            html_lines.append("<hr class='udec-hr' />")
            i += 1
            continue

        if line.startswith("# "):
            html_lines.append(f"<h1 class='title-h1'>{process_inline(line[2:])}</h1>")
        elif line.startswith("## "):
            html_lines.append(f"<h2 class='title-h2'>{process_inline(line[3:])}</h2>")
        elif line.startswith("### "):
            html_lines.append(f"<h3 class='title-h3'>{process_inline(line[4:])}</h3>")
        elif line.startswith("#### "):
            html_lines.append(f"<h4 class='title-h4'>{process_inline(line[5:])}</h4>")
        elif line.startswith("> "):
            html_lines.append(f"<blockquote class='callout-box'>{process_inline(line[2:])}</blockquote>")
        elif line.startswith("- ") or line.startswith("* "):
            html_lines.append(f"<li class='list-item'>{process_inline(line[2:])}</li>")
        elif re.match(r'^\d+\.\s+', line):
            m = re.match(r'^\d+\.\s+(.*)$', line)
            html_lines.append(f"<li class='list-item-num'>{process_inline(m.group(1))}</li>")
        elif line.strip() == "":
            html_lines.append("<div class='spacer'></div>")
        else:
            html_lines.append(f"<p>{process_inline(line)}</p>")
        i += 1

    if in_table:
        html_lines.append(flush_table())

    body_content = "\n".join(html_lines)

    html_document = f"""<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>{html.escape(title)}</title>
<style>
    @page {{
        size: A4;
        margin: 20mm 15mm 20mm 15mm;
        @bottom-right {{
            content: counter(page);
        }}
    }}
    body {{
        font-family: 'Segoe UI', Arial, sans-serif;
        font-size: 10.5pt;
        line-height: 1.5;
        color: #222222;
        background-color: #ffffff;
        margin: 0;
        padding: 0;
    }}
    .title-h1 {{
        color: #006633;
        font-size: 19pt;
        border-bottom: 2px solid #006633;
        padding-bottom: 5px;
        margin-top: 24px;
        margin-bottom: 12px;
        text-transform: uppercase;
        letter-spacing: 0.5px;
    }}
    .title-h2 {{
        color: #004d26;
        font-size: 14pt;
        border-bottom: 1px solid #D4AF37;
        padding-bottom: 4px;
        margin-top: 18px;
        margin-bottom: 10px;
    }}
    .title-h3 {{
        color: #006633;
        font-size: 12pt;
        margin-top: 14px;
        margin-bottom: 6px;
    }}
    .title-h4 {{
        color: #333333;
        font-size: 10.5pt;
        margin-top: 10px;
        margin-bottom: 4px;
    }}
    p {{
        margin: 0 0 8px 0;
        text-align: justify;
    }}
    .udec-hr {{
        border: 0;
        border-top: 2px solid #006633;
        margin: 18px 0;
    }}
    .udec-table {{
        width: 100%;
        border-collapse: collapse;
        margin: 14px 0;
        font-size: 9pt;
        page-break-inside: avoid;
    }}
    .udec-table th, .udec-table td {{
        border: 1px solid #cccccc;
        padding: 6px 10px;
        text-align: left;
    }}
    .udec-table th {{
        background-color: #006633;
        color: #ffffff;
        font-weight: 600;
        text-transform: uppercase;
        font-size: 8.5pt;
    }}
    .udec-table tr:nth-child(even) {{
        background-color: #f9fbf9;
    }}
    .callout-box {{
        background-color: #f0f7f2;
        border-left: 4px solid #006633;
        padding: 10px 14px;
        margin: 12px 0;
        font-style: italic;
        color: #1a4d2e;
        page-break-inside: avoid;
    }}
    .code-block {{
        background-color: #1e1e1e;
        color: #d4d4d4;
        padding: 10px;
        border-radius: 4px;
        font-family: 'Consolas', 'Courier New', monospace;
        font-size: 8.5pt;
        line-height: 1.4;
        overflow-x: auto;
        page-break-inside: avoid;
        margin: 10px 0;
    }}
    code {{
        background-color: #f2f2f2;
        color: #b81414;
        padding: 2px 4px;
        border-radius: 3px;
        font-family: 'Consolas', 'Courier New', monospace;
        font-size: 8.5pt;
    }}
    li.list-item {{
        margin-left: 20px;
        margin-bottom: 4px;
        list-style-type: square;
    }}
    li.list-item-num {{
        margin-left: 20px;
        margin-bottom: 4px;
        list-style-type: decimal;
    }}
    .spacer {{
        height: 6px;
    }}
    .header-banner {{
        background: linear-gradient(135deg, #006633 0%, #004d26 100%);
        color: white;
        padding: 12px 18px;
        border-radius: 4px;
        margin-bottom: 20px;
        display: flex;
        justify-content: space-between;
        align-items: center;
    }}
    .header-banner h2 {{
        margin: 0;
        font-size: 14pt;
        color: #ffffff;
        border: none;
    }}
    .header-banner p {{
        margin: 0;
        font-size: 9pt;
        color: #D4AF37;
    }}
</style>
</head>
<body>
    <div class="header-banner">
        <div>
            <h2>UNIVERSIDAD DE CUNDINAMARCA</h2>
            <p>FACULTAD DE INGENIERÍA | INGENIERÍA DE SISTEMAS Y COMPUTACIÓN | SECCIONAL UBATÉ</p>
        </div>
        <div style="text-align: right; font-size: 8.5pt; color: #ffffff;">
            <strong>PGC - NOVENO SEMESTRE</strong><br>Corte 3 (C3) – Vigencia 2026
        </div>
    </div>
    {body_content}
</body>
</html>
"""
    return html_document

def convert_file(rel_md_path, rel_pdf_path):
    abs_md_path = os.path.abspath(rel_md_path)
    abs_pdf_path = os.path.abspath(rel_pdf_path)
    html_temp = abs_md_path.replace('.md', '.temp.html')
    
    print(f"Procesando: {rel_md_path} -> {rel_pdf_path}")
    with open(abs_md_path, 'r', encoding='utf-8') as f:
        md_text = f.read()
    
    title = os.path.basename(abs_md_path).replace('.md', '').replace('_', ' ')
    html_content = markdown_to_html(md_text, title=title)
    
    with open(html_temp, 'w', encoding='utf-8') as f:
        f.write(html_content)
        
    file_url = f"file:///{html_temp.replace(os.sep, '/')}"
    
    cmd = [
        EDGE_PATH,
        "--headless",
        "--disable-gpu",
        "--no-pdf-header-footer",
        f"--print-to-pdf={abs_pdf_path}",
        file_url
    ]
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    if os.path.exists(html_temp):
        os.remove(html_temp)
        
    if os.path.exists(abs_pdf_path) and os.path.getsize(abs_pdf_path) > 0:
        print(f"OK: {os.path.basename(abs_pdf_path)} ({os.path.getsize(abs_pdf_path):,} bytes)")
        return True
    else:
        print(f"ERROR en {os.path.basename(abs_pdf_path)}: {result.stderr}")
        return False

def main():
    docs = [
        ("documentos/C3_Manual_de_Usuario_MediTime_Delgado&Arevalo.md",
         "documentos/C3_Manual_de_Usuario_MediTime_Delgado&Arevalo.pdf"),
        ("documentos/C3_Manual_Tecnico_MediTime_Delgado&Arevalo.md",
         "documentos/C3_Manual_Tecnico_MediTime_Delgado&Arevalo.pdf"),
        ("documentos/C3_Plan_de_Sostenibilidad_MediTime_Delgado&Arevalo.md",
         "documentos/C3_Plan_de_Sostenibilidad_MediTime_Delgado&Arevalo.pdf"),
        ("documentos/C3_Documentacion_Tecnica_de_Transferencia_MediTime_Delgado&Arevalo.md",
         "documentos/C3_Documentacion_Tecnica_de_Transferencia_MediTime_Delgado&Arevalo.pdf"),
    ]
    all_ok = True
    for md, pdf in docs:
        ok = convert_file(md, pdf)
        if not ok:
            all_ok = False
            
    if all_ok:
        print("\nTODOS LOS DOCUMENTOS PDF FUERON GENERADOS SATISFACTORIAMENTE!")
    else:
        print("\nHubo advertencias en algunos documentos.")

if __name__ == "__main__":
    main()
