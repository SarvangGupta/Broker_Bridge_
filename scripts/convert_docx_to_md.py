import sys
import os
import re
import docx
from docx.oxml.table import CT_Tbl
from docx.oxml.text.paragraph import CT_P
from docx.table import Table, _Cell
from docx.text.paragraph import Paragraph

sys.stdout.reconfigure(encoding='utf-8')


def iter_block_items(parent):
    if isinstance(parent, docx.document.Document):
        parent_elm = parent.element.body
    elif isinstance(parent, _Cell):
        parent_elm = parent._tc
    else:
        raise ValueError('Unknown parent')

    for child in parent_elm.iterchildren():
        if isinstance(child, CT_P):
            yield Paragraph(child, parent)
        elif isinstance(child, CT_Tbl):
            yield Table(child, parent)


def render_runs(p):
    groups = []
    for r in p.runs:
        if not r.text:
            continue
        bold = bool(r.bold)
        italic = bool(r.italic)
        if groups and groups[-1]['bold'] == bold and groups[-1]['italic'] == italic:
            groups[-1]['text'] += r.text
        else:
            groups.append({'text': r.text, 'bold': bold, 'italic': italic})
    
    res = ''
    for g in groups:
        txt = g['text']
        leading_ws = len(txt) - len(txt.lstrip())
        trailing_ws = len(txt) - len(txt.rstrip())
        
        ws_pre = txt[:leading_ws] if leading_ws > 0 else ''
        ws_post = txt[len(txt)-trailing_ws:] if trailing_ws > 0 else ''
        core = txt.strip()
        
        if not core:
            res += txt
            continue
            
        if g['bold'] and g['italic']:
            core_md = f'***{core}***'
        elif g['bold']:
            core_md = f'**{core}**'
        elif g['italic']:
            core_md = f'*{core}*'
        else:
            core_md = core
            
        res += ws_pre + core_md + ws_post

    res = res.replace('\ufffd', ' — ')
    res = res.replace('  — ', ' — ')
    res = res.replace(' —  ', ' — ')
    return res.strip()


def render_cell(cell):
    cell_lines = []
    for p in cell.paragraphs:
        rendered = render_runs(p)
        if rendered:
            cell_lines.append(rendered)
    full_cell = '<br>'.join(cell_lines)
    full_cell = full_cell.replace('|', '\\|')
    return full_cell if full_cell else ' '


def render_table(table):
    rows = []
    for row in table.rows:
        row_data = [render_cell(cell) for cell in row.cells]
        rows.append(row_data)
    
    if not rows:
        return ''
    
    num_cols = max(len(r) for r in rows)
    for r in rows:
        while len(r) < num_cols:
            r.append(' ')
            
    md_lines = []
    header = '| ' + ' | '.join(rows[0]) + ' |'
    divider = '| ' + ' | '.join(['---'] * num_cols) + ' |'
    md_lines.append(header)
    md_lines.append(divider)
    
    for row in rows[1:]:
        line = '| ' + ' | '.join(row) + ' |'
        md_lines.append(line)
        
    return '\n'.join(md_lines) + '\n'


def convert_docx_to_md(docx_path):
    doc = docx.Document(docx_path)
    md_out = []
    in_list = False
    
    for block in iter_block_items(doc):
        if isinstance(block, Paragraph):
            style = block.style.name
            rendered = render_runs(block)
            
            if not rendered:
                if in_list:
                    in_list = False
                    md_out.append('')
                continue
                
            if style == 'Heading 1':
                if in_list:
                    in_list = False
                    md_out.append('')
                md_out.append(f'# {rendered}\n')
            elif style == 'Heading 2':
                if in_list:
                    in_list = False
                    md_out.append('')
                md_out.append(f'## {rendered}\n')
            elif style == 'Heading 3':
                if in_list:
                    in_list = False
                    md_out.append('')
                md_out.append(f'### {rendered}\n')
            elif style == 'Heading 4':
                if in_list:
                    in_list = False
                    md_out.append('')
                md_out.append(f'#### {rendered}\n')
            elif style == 'List Bullet':
                in_list = True
                md_out.append(f'- {rendered}')
            elif style == 'List Number':
                in_list = True
                if re.match(r'^\d+\.', rendered):
                    md_out.append(rendered)
                else:
                    md_out.append(f'1. {rendered}')
            else:
                if in_list:
                    in_list = False
                    md_out.append('')
                md_out.append(f'{rendered}\n')
                
        elif isinstance(block, Table):
            if in_list:
                in_list = False
                md_out.append('')
            tbl_md = render_table(block)
            md_out.append(tbl_md)
            
    content = '\n'.join(md_out)
    content = re.sub(r'^1\.\s+(\d+\.\s+)', r'\1', content, flags=re.MULTILINE)
    return content


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python convert_docx_to_md.py <file.docx> [output.md]")
        sys.exit(1)
        
    input_file = sys.argv[1]
    if len(sys.argv) >= 3:
        output_file = sys.argv[2]
    else:
        output_file = os.path.splitext(input_file)[0] + '.md'
        
    md_content = convert_docx_to_md(input_file)
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(md_content)
        
    print(f"Successfully converted '{input_file}' to '{output_file}'")
