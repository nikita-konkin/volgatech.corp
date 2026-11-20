(() => {
  const weekdays = ['понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота'];
  const clean = text => text.trim().replace(/\s+/g, ' ');
  const dateKey = value => {
    const [day, month, year] = value.split('.');
    const monthDay = month.padStart(2, '0') + '-' + day.padStart(2, '0');
    return year ? year + '-' + monthDay : monthDay;
  };

  function parse(doc) {
    const table = doc.querySelector('table.TimeTableMain');
    if (!table) throw new Error('The portal timetable is missing');
    const rows = [];
    let weekday = 0;
    let slot = null;
    for (const row of table.rows) {
      if (row.classList.contains('day')) {
        const name = clean(row.querySelector('.dayDate')?.textContent ?? '');
        weekday = weekdays.indexOf(name.toLowerCase()) + 1;
        slot = null;
      } else if (row.classList.contains('lesson')) {
        const number = row.querySelector('.LessonNumber');
        const lesson = Number.parseInt(number?.textContent, 10);
        const times = number?.nextElementSibling?.textContent.match(/\d{1,2}:\d{2}/g);
        slot = lesson > 0 && times?.length === 2
          ? {lesson, begin: times[0].padStart(5, '0'), end: times[1].padStart(5, '0')}
          : null;
      } else if (row.classList.contains('SubjectTitle')) {
        const title = row.querySelector('.sbjCol');
        const groupCell = title && row.cells[title.cellIndex + 1];
        const roomCell = title && row.cells[title.cellIndex + 2];
        if (!weekday || !slot || !title || !groupCell || !roomCell) {
          throw new Error('The portal timetable row is incomplete');
        }
        const groupInfo = /^(.+?)\s+\((о|оз|з)\)(.*)$/i.exec(clean(groupCell.textContent));
        if (!groupInfo) continue;
        const [, group, form, details] = groupInfo;
        const titleText = clean(title.textContent);
        const subgroup = /\s+(\d+)\s*п\s*\/\s*г$/i.exec(titleText);
        const datePattern = /\b(\d{1,2}\.\d{1,2}(?:\.\d{4})?)(?:\s*[-–—]\s*(\d{1,2}\.\d{1,2}(?:\.\d{4})?))?/g;
        const dates = Array.from(details.matchAll(datePattern),
          ([, from, to]) => ({from: dateKey(from), to: dateKey(to ?? from)}));
        if (details.trim() && !dates.length) {
          throw new Error('The portal timetable date is unrecognized');
        }
        const week = Array.from(row.querySelector('span[class^="week"]')?.classList ?? [])
          .find(name => /^week(all|red|blue)$/.test(name))?.slice(4) ?? null;
        const kind = Array.from(row.querySelector('span[class^="work"], span[class^="ctrl"]')?.classList ?? [])
          .find(name => /^(work|ctrl)/.test(name)) ?? null;
        rows.push({
          weekday, ...slot, week, kind,
          discipline: subgroup ? titleText.slice(0, subgroup.index) : titleText,
          subgroup: subgroup?.[1] ?? null, group, form: form.toLowerCase(),
          dates, room: clean(roomCell.textContent)
        });
      }
    }
    return rows;
  }

  function run(action, request) {
    const reply = data => JSON.stringify(data);
    if (location.origin !== 'https://portal.volgatech.net' ||
        !/^\/my\/personal\/[^/]+\/sitepages\/[^/]+$/i.test(location.pathname)) {
      return reply({error: 'page'});
    }
    if (action === 'timetableReceipt') return reply(window.volgatechTimetable ?? {});
    const receipt = window.volgatechTimetable = {id: request.id, state: 'pending'};
    const url = new URL('Мое расписание занятий.aspx', location.href);
    const abort = new AbortController();
    const timeout = setTimeout(() => abort.abort(), 15000);
    fetch(url, {
      method: 'GET', credentials: 'same-origin', mode: 'same-origin',
      redirect: 'follow', cache: 'no-store', signal: abort.signal
    }).then(async response => {
      const landed = new URL(response.url);
      const path = landed.pathname.replace(/&authresend[0-9a-f]+$/i, '');
      if (!response.ok || landed.origin !== url.origin ||
          decodeURIComponent(path).toLowerCase() !== decodeURIComponent(url.pathname).toLowerCase()) {
        throw new Error('The portal timetable did not load');
      }
      const doc = new DOMParser().parseFromString(await response.text(), 'text/html');
      receipt.rows = parse(doc);
      receipt.state = 'ready';
    }).catch(() => {
      receipt.state = 'failed';
    }).finally(() => clearTimeout(timeout));
    return reply({started: true});
  }

  return {parse, run};
})()
