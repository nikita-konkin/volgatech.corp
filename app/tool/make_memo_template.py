#!/usr/bin/env python3
"""Build the blank memo template bundled with the app.

Input: a filled «служебная записка» about classes taught in a foreign language,
exactly as downloaded from portal.volgatech.net (SharePoint template).
Output: app/assets/memo/foreign_language_memo.docx — the same document with

  * every content control's text replaced by a {{marker}} the app fills in,
  * the class table cut down to its header plus two prototype rows (a
    teacher's first row and a continuation row) holding {{markers}},
  * names, phone numbers and the file's author removed — the output is
    committed to a public repository,
  * the table's header row marked to repeat on every page, and class rows
    kept whole at a page break (a month of classes runs to several pages;
    the portal's one-page original never needed either).

Everything else (styles, page setup, content controls, SharePoint metadata)
is kept byte-for-byte, so the result still registers on the portal.

Usage: python3 tool/make_memo_template.py <filled memo.docx>
Standard library only.
"""

import re
import sys
import zipfile
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / 'assets/memo/foreign_language_memo.docx'

# Content-control tag -> marker. Дата / Номер are left alone: the portal
# assigns them when the memo is registered. Название stays literal.
SDT_MARKERS = {
    'Подразделение': '{{department}}',
    'Адресат - Должность': '{{addressee_post}}',
    'Адресат - Фамилия И.О.': '{{addressee_name}}',
    'Структурное подразделение': '{{department_dative}}',
    'Подписывающий - Должность': '{{signer_post}}',
    'Подписывающий - И.О.Фамилия': '{{signer_name}}',
    'Исполнитель': '{{executor_name}}',
    'Телефон исполнителя': '{{executor_phone}}',
}

# Cell markers of the two prototype rows, left to right.
FIRST_ROW = [['{{teacher_name}}', '{{teacher_post}}'], ['{{date}}'],
             ['{{group}}'], ['{{discipline}}'], ['{{type}}'], ['{{hours}}']]
NEXT_ROW = [None, ['{{date}}'], ['{{group}}'], ['{{discipline}}'],
            ['{{type}}'], ['{{hours}}']]

RUN = re.compile(r'<w:r[ >].*?</w:r>', re.S)
PARA = re.compile(r'<w:p[ >].*?</w:p>', re.S)
CELL = re.compile(r'<w:tc>.*?</w:tc>', re.S)
ROW = re.compile(r'<w:tr[ >].*?</w:tr>', re.S)


def single_run(runs_xml: str, text: str) -> str:
    """One run carrying [text], formatted like the first run in [runs_xml]."""
    first = RUN.search(runs_xml)
    rpr = re.search(r'<w:rPr>.*?</w:rPr>', first.group(0), re.S) if first else None
    return f'<w:r>{rpr.group(0) if rpr else ""}<w:t xml:space="preserve">{text}</w:t></w:r>'


def set_paragraph_text(p: str, text: str) -> str:
    runs = RUN.findall(p)
    if not runs:
        return p.replace('</w:p>', single_run('', text) + '</w:p>')
    start = p.index(runs[0])
    end = p.rindex(runs[-1]) + len(runs[-1])
    return p[:start] + single_run(p[start:end], text) + p[end:]


def set_cell(cell: str, texts):
    if texts is None:
        return cell
    paras = PARA.findall(cell)
    assert len(paras) >= len(texts), (len(paras), texts)
    for p, t in zip(paras, texts):
        cell = cell.replace(p, set_paragraph_text(p, t), 1)
    for p in paras[len(texts):]:
        cell = cell.replace(p, set_paragraph_text(p, ''), 1)
    return cell


def set_row(row: str, cells_text) -> str:
    cells = CELL.findall(row)
    assert len(cells) == len(cells_text), (len(cells), len(cells_text))
    for c, texts in zip(cells, cells_text):
        row = row.replace(c, set_cell(c, texts), 1)
    # Rows get cloned by the app; paragraph ids must not repeat.
    return re.sub(r' w14:(?:paraId|textId)="[0-9A-F]+"', '', row)


def fill_sdts(doc: str) -> str:
    def repl(m):
        sdt = m.group(0)
        tag = re.search(r'<w:tag w:val="([^"]*)"', sdt).group(1)
        marker = SDT_MARKERS.get(tag)
        if marker is None:
            return sdt
        head, content, tail = re.match(
            r'(.*<w:sdtContent>)(.*)(</w:sdtContent>.*)', sdt, re.S).groups()
        runs = RUN.findall(content)
        start = content.index(runs[0])
        end = content.rindex(runs[-1]) + len(runs[-1])
        return head + content[:start] + single_run(content[start:end], marker) \
            + content[end:] + tail

    return re.sub(r'<w:sdt>.*?</w:sdt>', repl, doc, flags=re.S)


def with_row_flag(row: str, flag: str) -> str:
    """Adds the row property [flag] (e.g. <w:tblHeader/>) to [row]."""
    if flag in row:
        return row
    if '<w:trPr>' in row:
        return row.replace('<w:trPr>', f'<w:trPr>{flag}', 1)
    return re.sub(r'(<w:tr[^>]*>)', rf'\1<w:trPr>{flag}</w:trPr>', row, count=1)


def repeat_as_header(row: str) -> str:
    """Marks [row] as a header row Word repeats at the top of each page."""
    return with_row_flag(row, '<w:tblHeader/>')


def keep_whole(row: str) -> str:
    """Stops Word from splitting [row] across a page break."""
    return with_row_flag(row, '<w:cantSplit/>')


def cut_class_table(doc: str) -> str:
    starts = [m.start() for m in re.finditer(r'<w:tbl>', doc)]
    t0 = starts[1]  # [0] is the letterhead, [1] the class table
    t1 = doc.index('</w:tbl>', t0)
    table = doc[t0:t1]
    rows = ROW.findall(table)
    assert 'Преподаватель' in rows[0], 'unexpected table layout'
    new_rows = repeat_as_header(rows[0]) \
        + keep_whole(set_row(rows[1], FIRST_ROW)) \
        + keep_whole(set_row(rows[2], NEXT_ROW))
    first = table.index(rows[0])
    last = table.rindex(rows[-1]) + len(rows[-1])
    return doc[:t0] + table[:first] + new_rows + table[last:] + doc[t1:]


def scrub_core(core: str) -> str:
    for tag in ('dc:creator', 'cp:lastModifiedBy'):
        core = re.sub(rf'<{tag}>[^<]*</{tag}>', f'<{tag}></{tag}>', core)
    return core


def main(src: str) -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(src) as zin, \
            zipfile.ZipFile(OUT, 'w', zipfile.ZIP_DEFLATED) as zout:
        for item in zin.infolist():
            data = zin.read(item.filename)
            if item.filename == 'word/document.xml':
                doc = data.decode('utf-8')
                doc = cut_class_table(fill_sdts(doc))
                data = doc.encode('utf-8')
            elif item.filename == 'docProps/core.xml':
                data = scrub_core(data.decode('utf-8')).encode('utf-8')
            zout.writestr(item, data)
    print(f'wrote {OUT}')


if __name__ == '__main__':
    main(sys.argv[1])
