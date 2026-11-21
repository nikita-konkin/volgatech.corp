const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

function script(globals) {
  const asset = path.join(__dirname, '../assets/portal/timetable.js');
  return vm.runInNewContext(fs.readFileSync(asset, 'utf8'), globals);
}

function documentWith(...rows) {
  return {querySelector: selector => selector === 'table.TimeTableMain' ? {rows} : null};
}

function row(className, selectors, cells = []) {
  return {
    classList: {contains: name => className === name},
    querySelector: selector => selectors[selector] ?? null,
    cells
  };
}

function day(name) {
  return row('day', {'.dayDate': {textContent: name}});
}

function lesson(number, times) {
  return row('lesson', {
    '.LessonNumber': {textContent: number, nextElementSibling: {textContent: times}}
  });
}

function subject(title, group, room, week, kind) {
  const discipline = {textContent: title, cellIndex: 3};
  return row('SubjectTitle', {
    '.sbjCol': discipline,
    'span[class^="week"]': {classList: [week]},
    'span[class^="work"], span[class^="ctrl"]': {classList: [kind]}
  }, [{}, {}, {}, discipline, {textContent: group}, {textContent: room}]);
}

test('parallel subjects retain the day and their irregular lesson times', () => {
  const number = 3 + Math.floor(Math.random() * 5);
  const doc = documentWith(
    day(' суббота '),
    lesson(String(number), '13:1514:00'),
    subject(' Практикум   по теням 4 п/г ', 'МШ-389 (оз) - 3 неделя (30.11.2043 - 06.12.2043)',
      '719ж (IX)', 'weekblue', 'workLab'),
    subject('Измерение ветра', 'ФКм-17 (о) (14.12)', 'павильон 8', 'weekred', 'ctrlTestMark'),
    day('вторник'),
    lesson('2', '9:23 11:06'),
    subject('Топология садов', 'СЖ-55 (з)', '8 (II)', 'weekall', 'workPract')
  );
  assert.deepEqual(JSON.parse(JSON.stringify(script().parse(doc))), [
    {weekday: 6, lesson: number, begin: '13:15', end: '14:00', week: 'blue',
      kind: 'workLab', discipline: 'Практикум по теням', subgroup: '4', group: 'МШ-389',
      form: 'оз', dates: [{from: '2043-11-30', to: '2043-12-06'}], room: '719ж (IX)'},
    {weekday: 6, lesson: number, begin: '13:15', end: '14:00', week: 'red',
      kind: 'ctrlTestMark', discipline: 'Измерение ветра', subgroup: null, group: 'ФКм-17',
      form: 'о', dates: [{from: '12-14', to: '12-14'}], room: 'павильон 8'},
    {weekday: 2, lesson: 2, begin: '09:23', end: '11:06', week: 'all',
      kind: 'workPract', discipline: 'Топология садов', subgroup: null, group: 'СЖ-55',
      form: 'з', dates: [], room: '8 (II)'}
  ], 'a portal subject lost its slot or timetable details');
});

test('a page without the timetable cannot replace the cached rows', () => {
  assert.throws(() => script().parse(documentWithMissingTable()),
    {message: 'The portal timetable is missing'},
    'a page without the timetable was accepted');
});

function documentWithMissingTable() {
  return {querySelector: () => null};
}

test('the bridge reads only the same-origin timetable and returns its rows', {timeout: 1000}, async () => {
  const calls = [];
  let complete;
  const completed = new Promise(resolve => { complete = resolve; });
  const bridge = script({
    location: new URL('https://portal.volgatech.net/my/personal/example-9/SitePages/Workload.aspx'),
    window: {},
    URL,
    AbortController,
    setTimeout,
    clearTimeout(id) {
      clearTimeout(id);
      complete();
    },
    async fetch(url, options) {
      calls.push([String(url), options.method, options.credentials, options.mode, options.redirect]);
      return {ok: true, url: url.href + '&AuthResendc84e9d',
        text: async () => '<table class="TimeTableMain"></table>'};
    },
    DOMParser: class {
      parseFromString(html, type) {
        return html.includes('TimeTableMain') && type === 'text/html'
          ? documentWith() : documentWithMissingTable();
      }
    }
  });
  bridge.run('timetableStart', {id: 39});
  await completed;
  assert.deepEqual([calls, JSON.parse(bridge.run('timetableReceipt'))], [
    [[`https://portal.volgatech.net/my/personal/example-9/SitePages/${encodeURIComponent('Мое расписание занятий.aspx')}`,
      'GET', 'same-origin', 'same-origin', 'follow']],
    {id: 39, state: 'ready', rows: []}
  ], 'the WebView did not make a read-only timetable request');
});
