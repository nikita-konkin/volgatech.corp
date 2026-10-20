#!/usr/bin/env python3
"""Build the blank hourly-load report template bundled with the app.

Input: a filled «Приложение к форме 28 — Отчет по видам выполненных работ»
(Word, landscape A4, as the department hands it out).
Output: app/assets/hourly/form28_appendix.docx — the same document with

  * the teacher's post and name (the underlined text after «Должность, ФИО
    преподавателя») replaced by {{teacher}},
  * the table cut down to its header, one prototype class row holding
    {{date}} {{hours}} {{group}} {{type}} {{discipline}} {{topic}}, and the
    «Итого» row with {{total}},
  * the head of department's post and name in the signature line replaced
    by {{signer_post}} and {{signer_name}},
  * the file's author and last editor removed — the output is committed to
    a public repository,
  * the table's header row marked to repeat on every page, and class rows
    kept whole at a page break,
  * the «Вид занятия» column widened from the topic column's share, so
    «Лабораторная» fits on one line (the form's own width only fits
    «Практика»).

Everything else (fonts, column widths, page setup, the spacing that lines
the signature up) is kept as it was.

Usage: python3 tool/make_hourly_template.py <filled report.docx>
Standard library only.
"""

import re
import sys
import zipfile
from pathlib import Path

from make_memo_template import (PARA, ROW, RUN, keep_whole, repeat_as_header,
                                scrub_core, set_row)

OUT = Path(__file__).resolve().parent.parent / 'assets/hourly/form28_appendix.docx'

CLASS_ROW = [['{{date}}'], ['{{hours}}'], ['{{group}}'], ['{{type}}'],
             ['{{discipline}}'], ['{{topic}}']]
TOTAL_ROW = [None, ['{{total}}'], None, None, None, None]

# Column widths (twips): «Вид занятия» takes this much from the topic column.
WIDEN_TYPE = 330

TEXT = re.compile(r'(<w:t(?: [^>]*)?>)([^<]*)(</w:t>)')


def run_text(run: str) -> str:
    return ''.join(m.group(2) for m in TEXT.finditer(run))


def with_text(run: str, text: str) -> str:
    """[run] carrying [text] in its first <w:t>, its other <w:t>s emptied."""
    first = True

    def repl(m):
        nonlocal first
        t, first = (text if first else ''), False
        return f'<w:t xml:space="preserve">{t}</w:t>'

    return TEXT.sub(repl, run)


def fill_teacher(doc: str) -> str:
    """The underlined post and name after «Должность, ФИО преподавателя»."""
    p = next(p for p in PARA.findall(doc) if 'ФИО преподавателя' in p)
    out, done = p, False
    for run in RUN.findall(p):
        if '<w:u ' not in run or not run_text(run).strip():
            continue  # the label, and the underlined blanks that pad it
        out = out.replace(run, with_text(run, '' if done else '{{teacher}}'), 1)
        done = True
    assert done, 'no teacher name in the report'
    return doc.replace(p, out, 1)


def fill_signer(doc: str) -> str:
    """«Зав. кафедрой … /И.О. Фамилия/» below the table."""
    tail = doc.index('</w:tbl>')
    p = next(p for p in PARA.findall(doc[tail:]) if '/' in run_text(p))
    out, phase = p, 'post'

    def put(run, text):
        nonlocal out
        out = out.replace(run, with_text(run, text), 1)

    for run in RUN.findall(p):
        text = run_text(run)
        if phase == 'post' and '/' not in text:
            if text.strip():
                # The post; its trailing spaces push the name to the right.
                lead = '' if '{{signer_post}}' in out else '{{signer_post}}'
                put(run, lead + text[len(text.rstrip()):])
        elif phase == 'post':
            before, rest = text.split('/', 1)
            if '/' in rest:
                put(run, before + '/{{signer_name}}/' + rest.split('/', 1)[1])
                phase = 'done'
            else:
                put(run, before + '/{{signer_name}}')
                phase = 'name'
        elif phase == 'name':
            # The rest of the name, up to the closing slash.
            put(run, text[text.index('/'):] if '/' in text else '')
            if '/' in text:
                phase = 'done'
    assert '{{signer_post}}' in out and '{{signer_name}}' in out, 'no signature'
    return doc.replace(p, out, 1)


def cut_table(doc: str) -> str:
    t0 = doc.index('<w:tbl>')
    t1 = doc.index('</w:tbl>', t0)
    table = doc[t0:t1]
    rows = ROW.findall(table)
    assert 'Дата занятия' in run_text(rows[0]), 'unexpected table layout'
    assert 'Итого' in run_text(rows[-1]), 'no «Итого» row'
    new_rows = repeat_as_header(rows[0]) \
        + keep_whole(set_row(rows[1], CLASS_ROW)) \
        + keep_whole(set_row(rows[-1], TOTAL_ROW))
    first = table.index(rows[0])
    last = table.rindex(rows[-1]) + len(rows[-1])
    table = widen_type(table[:first] + new_rows + table[last:])
    return doc[:t0] + table + doc[t1:]


def widen_type(table: str) -> str:
    """The 4th column wider and the 6th narrower by [WIDEN_TYPE], in the
    grid and in every cell."""
    widths = [int(w) for w in re.findall(r'<w:gridCol w:w="(\d+)"/>', table)]
    assert len(widths) == 6, widths
    old_type, old_topic = widths[3], widths[5]
    new = {old_type: old_type + WIDEN_TYPE, old_topic: old_topic - WIDEN_TYPE}
    assert len(new) == 2, 'type and topic columns share a width'

    def repl(m):
        w = int(m.group(2))
        return f'{m.group(1)}{new.get(w, w)}"' if w in new else m.group(0)

    return re.sub(r'(<w:(?:gridCol|tcW) w:w=")(\d+)"', repl, table)


def main(src: str) -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(src) as zin, \
            zipfile.ZipFile(OUT, 'w', zipfile.ZIP_DEFLATED) as zout:
        for item in zin.infolist():
            data = zin.read(item.filename)
            if item.filename == 'word/document.xml':
                doc = data.decode('utf-8')
                doc = fill_signer(cut_table(fill_teacher(doc)))
                data = doc.encode('utf-8')
            elif item.filename == 'docProps/core.xml':
                data = scrub_core(data.decode('utf-8')).encode('utf-8')
            zout.writestr(item, data)
    print(f'wrote {OUT}')


if __name__ == '__main__':
    main(sys.argv[1])
