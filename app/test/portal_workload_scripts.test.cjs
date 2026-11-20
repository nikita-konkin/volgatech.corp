const assert = require('node:assert/strict');
const {randomInt} = require('node:crypto');
const {readFileSync} = require('node:fs');
const {join} = require('node:path');
const {test} = require('node:test');
const {runInNewContext} = require('node:vm');

function workloadScript() {
  return readFileSync(join(__dirname, '../assets/portal/workload.js'), 'utf8');
}

function portal(discipline) {
  const location = new URL('https://portal.volgatech.net/my/personal/test/sitepages/Нагрузка на первую половину дня.aspx');
  const writes = [];
  const heading = (level, textContent) => ({
    className: 'hourspps-group-' + level,
    querySelector: () => ({textContent})
  });
  const cell = {classList: {contains: () => false}, value: '0'};
  const table = {
    id: 'testGrid_ctl00',
    rows: [{cells: [{id: 'HoursAuditLec17_MultiHeader93', colSpan: 1}]}],
    tBodies: [{
      querySelector: () => null,
      rows: [
        heading(1, 'Тип: Основное место работы'),
        heading(2, 'Семестр: 1 семестр'),
        heading(3, 'Дисциплина: ' + discipline),
        heading(4, 'Специальность: ИСТ 3 курс'),
        {className: 'hourspps-item', classList: {contains: () => true}, id: 'row7', cells: [cell]}
      ]
    }]
  };
  const batch = {
    get_currentlyEditedCell: () => null,
    get_currentlyEditedRow: () => null,
    getCellValue: target => target.value,
    hasChanges: () => false,
    changeCellValue(target, value) {
      writes.push(value);
      target.value = value;
    },
    saveChanges() {
      writes.push('save');
    }
  };
  const grid = {
    get_masterTableView: () => table,
    get_batchEditingManager: () => batch
  };
  const dropdown = label => {
    const item = {get_text: () => label, get_value: () => label, get_enabled: () => true};
    return {get_items: () => ({get_count: () => 1, getItem: () => item}), get_selectedItem: () => item};
  };
  const filters = {ddlPerson: 'А. П. Соснин', ddlMonth: 'ноябрь 2026', ddlStudyYear: '2026/2027', ddlKafedra: 'Геодезия'};
  const document = {
    querySelector(query) {
      if (query.includes('RadDropDownList')) {
        const id = Object.keys(filters).find(name => query.includes(name));
        return {id};
      }
      return query.includes('_btnSave') ? {} : null;
    },
    querySelectorAll: () => [table],
    getElementById: () => null
  };
  const window = {$find: id => id === 'testGrid' ? grid : dropdown(filters[id])};
  const context = {
    window, location, document, URL,
    performance: {timeOrigin: 1},
    fetch() {
      writes.push('fetch');
    }
  };
  return {context, window, writes, grid, batch};
}

test('The shared script registers its workload function in the browser', () => {
  const window = {name: String(randomInt(17, 791))};
  runInNewContext(workloadScript(), {window});
  assert.equal(typeof window.volgatechWorkload, 'function', 'the workload function was not registered');
});

test('Android can append its arguments to the shared script expression', () => {
  const number = randomInt(18, 381);
  const {context} = portal('Рельеф №' + number);
  const data = runInNewContext(workloadScript() + '("inspect", null)', context);
  assert.equal(JSON.parse(data).cells[0].discipline, 'Рельеф №' + number, 'the Android call did not return the inspected discipline');
});

test('Android can still save the grid and read its receipt after re-evaluating the script', async () => {
  const hours = randomInt(11, 521);
  const id = 'receipt-' + randomInt(47, 789);
  const {context, window, writes, grid, batch} = portal('Съёмка №' + randomInt(33, 653));
  context.document.getElementById = () => ({
    action: context.location.href, method: 'POST', elements: {__VIEWSTATE: {value: 'state'}}
  });
  grid.UniqueID = 'testGrid';
  grid.ClientSettings = {PostBackFunction: "__doPostBack('{0}','{1}')"};
  const command = 'FireCommand:3;BatchEdit;u(test)';
  batch.saveChanges = () => window.__doPostBack(grid.UniqueID, command);
  Object.assign(context, {
    FormData: class {},
    URLSearchParams,
    AbortController,
    setTimeout: () => 9,
    clearTimeout: () => {},
    async fetch(url, options) {
      writes.push([url, options.body.get('__EVENTTARGET'), options.body.get('__EVENTARGUMENT')]);
      return {ok: true, url};
    }
  });
  const evaluate = (action, request) =>
    JSON.parse(runInNewContext(workloadScript() + '(' + JSON.stringify(action) + ', ' + JSON.stringify(request) + ')', context));
  const {scope, cells} = evaluate('inspect', null);
  const submitted = evaluate('submit', {scope, id, changes: {[cells[0].key]: {before: 0, after: hours * 100}}});
  await Promise.resolve();
  const receipt = evaluate('receipt', null);
  assert.deepEqual(
    [submitted, receipt, writes],
    [{started: true}, {id, state: 'received'}, [hours, [context.location.href, grid.UniqueID, command]]],
    'Android did not save the requested hours and preserve its submission receipt'
  );
});

test('Filling writes academic hours to Telerik without saving or posting them', () => {
  const hours = randomInt(17, 439) / 4;
  const {context, window, writes} = portal('Почвоведение №' + randomInt(32, 912));
  runInNewContext(workloadScript(), context);
  const {scope, cells} = JSON.parse(window.volgatechWorkload('inspect', null));
  const result = JSON.parse(window.volgatechWorkload('fill', {
    scope, changes: {[cells[0].key]: {before: 0, after: hours * 100}}
  }));
  assert.deepEqual([result, writes], [{filled: true}, [hours]], 'filling did not write only the requested value');
});

test('A stale preview does not change any Telerik values', () => {
  const hours = randomInt(31, 592);
  const {context, window, writes} = portal('Картография №' + randomInt(15, 782));
  runInNewContext(workloadScript(), context);
  const {scope, cells} = JSON.parse(window.volgatechWorkload('inspect', null));
  const result = JSON.parse(window.volgatechWorkload('fill', {
    scope, changes: {[cells[0].key]: {before: 25, after: hours * 100}}
  }));
  assert.deepEqual([result, writes], [{error: 'changed'}, []], 'the stale preview was not rejected without modifying the grid');
});

test('Discipline names fold Cyrillic case and ё and collapse internal whitespace', () => {
  const {workloadName} = require('../web/portal/fill.js');
  const number = randomInt(63, 384);
  assert.equal(workloadName(' \u0085\tСъЁмКИ\n\u00a0№' + number + ' \t'), 'съемки №' + number, 'the discipline was not normalized like the timetable');
});

test('Matching hides other departments and leaves competing rows for the teacher', () => {
  const {workloadMatches} = require('../web/portal/fill.js');
  const hours = randomInt(17, 189);
  const lines = [
    {discipline: 'Учёт  леса', column: 'HoursAuditLec', hours},
    {discipline: 'Учёт леса', column: 'HoursAuditLab', hours},
    {discipline: 'Гидрология', column: 'HoursAuditLec', hours},
    {discipline: 'ГИДРОЛОГИЯ', column: 'HoursAuditLab', hours}
  ];
  const row = {discipline: 'учет леса', column: 'HoursAuditLec', semester: '1 семестр', amount: 0};
  const choices = [{...row, key: 'k53'}, {...row, key: 'u19'}];
  const cells = [...choices, {...row, key: 'x17', amount: 250}, {...row, key: 'z29', semester: '2 семестр'}];
  const {matches, hidden, hiddenHours} = workloadMatches(lines, cells, '1 семестр');
  assert.deepEqual(
    [matches.map(({choices, suggested}) => [choices.map(cell => cell.key), suggested]), hidden, hiddenHours],
    [[[['k53', 'u19'], ''], [[], '']], 1, hours * 2],
    'the matches did not distinguish competing, occupied, missing-column and hidden lines'
  );
});

test('The preview combines timetable lines assigned to the same portal cell', () => {
  const {workloadChanges} = require('../web/portal/fill.js');
  const hours = randomInt(53, 740);
  const cell = {key: 'g' + randomInt(43, 808), amount: 0};
  const matches = [hours, hours + 3, 19].map(value => ({line: {hours: value}, choices: [cell]}));
  assert.deepEqual(
    workloadChanges(matches, [cell.key, cell.key, '']),
    [{cell, before: 0, after: (2 * hours + 3) * 100}],
    'the preview did not combine only the chosen lines for the cell'
  );
});

test('The open form must have the copied month and semester', () => {
  const {workloadPeriodError} = require('../web/portal/fill.js');
  const year = randomInt(2028, 2083);
  const report = {
    filters: {month: {selected: {label: '  МАРТ ' + year}}},
    cells: [{semester: '2 семестр'}]
  };
  assert.deepEqual([
    workloadPeriodError({month: year + '-03', semester: '2 семестр'}, report),
    workloadPeriodError({month: year + '-04', semester: '2 семестр'}, report),
    workloadPeriodError({month: year + '-03', semester: '1 семестр'}, report),
    workloadPeriodError({month: year + '-03', semester: '2 семестр'}, {...report, cells: [{semester: '1 семестр'}]})
  ], ['', 'month', 'semester', 'semester'], 'the portal period was not checked against the payload');
});

test('The loader resolves the shared asset from the script URL under each deployment', () => {
  const version = String(randomInt(23, 731));
  const port = randomInt(49152, 65536);
  const roots = [
    'https://konkin-nikita.ru/volgatech.corp/',
    'https://nikita-konkin.gitverse.site/volgatech-corp/',
    'http://localhost:' + port + '/'
  ];
  const script = readFileSync(join(__dirname, '../web/portal/fill.js'), 'utf8');
  const loaded = [];
  for (const root of roots) {
    runInNewContext(script, {
      URL,
      window: {},
      location: {origin: 'https://portal.volgatech.net'},
      document: {
        currentScript: {src: root + 'portal/fill.js?v=' + version},
        createElement: () => ({}),
        getElementById: () => null,
        head: {append: tag => loaded.push([tag.src, tag.referrerPolicy])}
      }
    });
  }
  assert.deepEqual(
    loaded,
    roots.map(root => [root + 'assets/assets/portal/workload.js?v=' + version, 'no-referrer']),
    'the shared asset URLs did not preserve the deployment base and version'
  );
});

test('The guide creates an executable bookmark for its own deployment', () => {
  const port = randomInt(49152, 65536);
  const root = 'http://localhost:' + port + '/app-example/';
  const html = readFileSync(join(__dirname, '../web/bookmark.html'), 'utf8');
  const script = /<script>([\s\S]+)<\/script>/.exec(html)[1];
  const elements = {'bookmark': {}, 'bookmark-code': {}};
  runInNewContext(script, {
    URL, location: new URL(root + 'bookmark.html?guide=quick'),
    document: {getElementById: name => elements[name]}
  });
  const tags = [];
  runInNewContext(elements.bookmark.href.slice('javascript:'.length), {
    location: {origin: 'https://portal.volgatech.net'},
    document: {createElement: () => ({}), head: {append: tag => tags.push(tag)}}
  });
  assert.deepEqual(
    [tags[0].src.replace(/\?v=\d+$/, ''), tags[0].referrerPolicy, elements['bookmark-code'].value],
    [root + 'portal/fill.js', 'no-referrer', elements.bookmark.href],
    'the bookmark did not load the versioned script or provide the identical address for manual setup'
  );
});

test('The panel refuses a different payload version and shows the hours before filling', async () => {
  const hours = randomInt(11, 867);
  const discipline = 'Геодезия №' + randomInt(27, 486);
  const {context, window, writes} = portal(discipline);
  function element(tag) {
    return {
      tag, textContent: '', value: '', children: [], isConnected: true,
      listeners: {},
      append(...children) {
        this.children.push(...children);
      },
      replaceChildren(...children) {
        this.children = children;
      },
      addEventListener(type, handler) {
        this.listeners[type] = handler;
      },
      attachShadow() {
        const root = element('shadow');
        this.append(root);
        return root;
      },
      setAttribute() {},
      focus() {},
      remove() {}
    };
  }
  function* tree(node) {
    yield node;
    for (const child of node.children) yield* tree(child);
  }
  const body = element('body');
  const head = element('head');
  Object.assign(context.document, {
    body,
    head,
    createElement: element,
    currentScript: {src: 'https://example.test/sample/portal/fill.js?v=71'}
  });
  context.navigator = {clipboard: {readText: async () => ''}};
  const script = readFileSync(join(__dirname, '../web/portal/fill.js'), 'utf8');
  runInNewContext(script, context);
  runInNewContext(workloadScript(), context);
  head.children[0].onload();
  await Promise.resolve();
  const panel = [...tree(body)];
  const input = panel.find(node => node.tag === 'textarea');
  const check = panel.find(node => node.tag === 'button' && node.textContent === 'Проверить часы');
  const fill = panel.find(node => node.tag === 'button' && node.textContent === 'Заполнить');
  const payload = {
    month: '2026-11', semester: '1 семестр',
    lines: [{discipline, column: 'HoursAuditLec', hours, groups: ['ГД-51 (2)']}]
  };
  input.value = JSON.stringify({...payload, volgatech: 'workload/' + randomInt(2, 30)});
  check.listeners.click();
  const refused = [...tree(body)].some(node => node.textContent.includes('Версия данных не поддерживается')) && fill.disabled;
  input.value = JSON.stringify({...payload, volgatech: 'workload/1'});
  check.listeners.click();
  const preview = [...tree(body)].filter(node => node.tag === 'li' || node.textContent.startsWith('Итого')).map(node => node.textContent);
  const before = writes.slice();
  fill.listeners.click();
  const savePrompt = [...tree(body)].some(node => node.textContent === 'Проверьте форму и нажмите «Сохранить» на портале');
  assert.deepEqual(
    [refused, preview, before, writes, savePrompt, typeof window.volgatechWorkload],
    [true, [discipline + ' · Лекции · ИСТ 3 курс · Основное место работы · 0 → ' + hours + ' ч.', 'Итого · ' + hours + ' ч.'],
      [], [hours], true, 'function'],
    'the panel did not reject the invalid version, preview the hours, and leave saving to the teacher'
  );
});
