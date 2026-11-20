(() => {
  const columns = {
    HoursAuditLec: 'Лекции',
    HoursAuditLab: 'Лабораторные',
    HoursAuditPract: 'Практические',
    HoursExam: 'Экзамен',
    HoursTest: 'Зачёт (БРК)',
    HoursConsultExam: 'Консультации перед экзаменом',
    HoursStudyPract: 'Учебная практика'
  };
  const months = [
    'январь', 'февраль', 'март', 'апрель', 'май', 'июнь',
    'июль', 'август', 'сентябрь', 'октябрь', 'ноябрь', 'декабрь'
  ];
  const panelId = 'volgatech-workload-panel';
  const loaderId = 'volgatech-workload-loader';
  const workloadName = value => value.replace(/^[\s\u0085]+|[\s\u0085]+$/g, '')
    .toLowerCase().replace(/ё/g, 'е').replace(/\s+/g, ' ');
  const hoursText = amount => (amount / 100).toFixed(2).replace(/\.00$/, '').replace('.', ',');

  function workloadPayload(text) {
    let payload;
    try {
      payload = JSON.parse(text);
    } catch {
      throw new Error('Вставьте данные из раздела «Учебная нагрузка»');
    }
    if (payload?.volgatech !== 'workload/1') {
      throw new Error('Версия данных не поддерживается, скопируйте часы заново');
    }
    if (typeof payload.month !== 'string' || !/^\d{4}-(0[1-9]|1[0-2])$/.test(payload.month) ||
        !['1 семестр', '2 семестр'].includes(payload.semester) ||
        !Array.isArray(payload.lines) || !payload.lines.length ||
        !payload.lines.every(line => line && typeof line.discipline === 'string' &&
          workloadName(line.discipline) && typeof line.column === 'string' && Object.hasOwn(columns, line.column) &&
          Number.isSafeInteger(line.hours) && line.hours > 0 &&
          Array.isArray(line.groups) && line.groups.every(group => typeof group === 'string')) ||
        !Number.isSafeInteger(payload.lines.reduce((sum, line) => sum + line.hours * 100, 0))) {
      throw new Error('Данные о нагрузке повреждены, скопируйте часы заново');
    }
    return payload;
  }

  function workloadPeriodError(payload, report) {
    const [name, year, extra] = workloadName(report.filters.month.selected.label).split(' ');
    const month = months.indexOf(name) + 1;
    if (extra || !month || year + '-' + String(month).padStart(2, '0') !== payload.month) return 'month';
    const semester = month >= 2 && month <= 8 ? '2 семестр' : '1 семестр';
    if (semester !== payload.semester ||
        (report.cells.length > 0 && !report.cells.some(cell => workloadName(cell.semester) === semester))) {
      return 'semester';
    }
    return '';
  }

  function workloadMatches(lines, cells, semester) {
    const byDiscipline = new Map();
    for (const cell of cells) {
      const name = workloadName(cell.discipline);
      if (!byDiscipline.has(name)) byDiscipline.set(name, []);
      byDiscipline.get(name).push(cell);
    }
    const matches = [];
    const hidden = new Set();
    let hiddenHours = 0;
    for (const line of lines) {
      const name = workloadName(line.discipline);
      const rows = byDiscipline.get(name);
      if (!rows) {
        hidden.add(name);
        hiddenHours += line.hours;
        continue;
      }
      const eligible = rows.filter(cell => cell.column === line.column && workloadName(cell.semester) === semester);
      const choices = eligible.filter(cell => cell.amount === 0);
      const suggested = eligible.length === 1 && choices.length === 1 ? choices[0].key : '';
      matches.push({line, choices, suggested, hasColumn: eligible.length > 0});
    }
    return {matches, hidden: hidden.size, hiddenHours};
  }

  function workloadChanges(matches, selected) {
    const changes = new Map();
    matches.forEach(({line, choices}, index) => {
      const cell = choices.find(choice => choice.key === selected[index]);
      if (!cell) return;
      const amount = (changes.get(cell.key)?.after ?? 0) + line.hours * 100;
      changes.set(cell.key, {cell, before: cell.amount, after: amount});
    });
    return Array.from(changes.values());
  }

  function element(tag, text) {
    const node = document.createElement(tag);
    if (text !== undefined) node.textContent = text;
    return node;
  }

  function button(text, handler) {
    const node = element('button', text);
    node.type = 'button';
    node.addEventListener('click', handler);
    return node;
  }

  function option(value, text) {
    const node = element('option', text);
    node.value = value;
    return node;
  }

  function hiddenSummary(count, hours) {
    const last = count % 10;
    const teens = count % 100 >= 11 && count % 100 <= 14;
    const noun = teens || last === 0 || last >= 5 ? 'дисциплин' : last === 1 ? 'дисциплина' : 'дисциплины';
    return 'Скрыто ' + count + ' ' + noun + ' других кафедр · ' + hours + ' ч.';
  }

  function workloadPanel(run) {
    const host = element('div');
    host.id = panelId;
    const root = host.attachShadow({mode: 'open'});
    const styles = element('style', [
      ':host{all:initial;position:fixed;right:12px;bottom:12px;z-index:2147483647;width:min(440px,calc(100vw - 24px));color:#182238;font:14px/1.4 system-ui,sans-serif}',
      'section{box-sizing:border-box;max-height:calc(100vh - 24px);overflow:auto;background:#fff;border:1px solid #a8b3c5;border-radius:10px;padding:14px;box-shadow:0 4px 18px #18223840}',
      'header{display:flex;align-items:center;justify-content:space-between;gap:8px} h2{font-size:17px;margin:0} p{margin:8px 0} ul{margin:8px 0;padding-left:22px}',
      'button,select,textarea{font:inherit;color:inherit} button{margin:4px 6px 4px 0} button:disabled{opacity:.55} textarea,select{box-sizing:border-box;width:100%;margin:4px 0}'
    ].join(''));
    const panel = element('section');
    panel.setAttribute('aria-label', 'Заполнить из Волгатех');
    const header = element('header');
    header.append(element('h2', 'Заполнить из Волгатех'), button('Закрыть', () => host.remove()));
    const label = element('label', 'Данные из раздела «Учебная нагрузка»');
    const input = element('textarea');
    input.rows = 3;
    input.spellcheck = false;
    label.append(input);
    const status = element('p');
    status.setAttribute('role', 'status');
    const preview = element('div');
    const changes = element('div');
    let current;
    let filled = false;
    const fill = button('Заполнить', apply);
    fill.disabled = true;
    panel.append(header, label, button('Вставить из буфера', readClipboard),
      button('Проверить часы', prepare), status, preview, changes, fill);
    root.append(styles, panel);
    document.body.append(host);
    input.addEventListener('input', reset);
    readClipboard();

    function reset() {
      current = null;
      preview.replaceChildren();
      changes.replaceChildren();
      fill.disabled = true;
      status.textContent = filled ? 'Проверьте форму и нажмите «Сохранить» на портале' : '';
    }

    async function readClipboard() {
      const original = input.value;
      try {
        const text = await navigator.clipboard.readText();
        if (!host.isConnected || input.value !== original || current || filled) return;
        if (text) {
          input.value = text;
          prepare();
          return;
        }
      } catch {
        if (!host.isConnected || input.value !== original || current || filled) return;
      }
      if (filled) return;
      status.textContent = 'Вставьте скопированные данные в поле и нажмите «Проверить часы»';
      input.focus();
    }

    function renderChanges() {
      current.changes = workloadChanges(current.matches, current.selected);
      const list = element('ul');
      let total = 0;
      for (const {cell, before, after} of current.changes) {
        total += after;
        list.append(element('li', [
          cell.discipline, columns[cell.column], cell.specialty, cell.appointment,
          hoursText(before) + ' → ' + hoursText(after) + ' ч.'
        ].join(' · ')));
      }
      changes.replaceChildren(list, element('strong', 'Итого · ' + hoursText(total) + ' ч.'));
      fill.disabled = !current.changes.length;
    }

    function prepare() {
      reset();
      if (filled) return;
      try {
        const payload = workloadPayload(input.value);
        const info = run('info');
        if (info.error === 'page') throw new Error('Откройте форму «Нагрузка на первую половину дня»');
        if (info.error) throw new Error('Дождитесь загрузки формы и проверьте часы снова');
        if (info.mode !== 'edit') throw new Error('Переведите форму портала в режим редактирования и запустите закладку снова');
        const report = run('inspect');
        if (report.error) throw new Error('Завершите редактирование ячейки или обновите форму и проверьте часы снова');
        const periodError = workloadPeriodError(payload, report);
        if (periodError === 'month') throw new Error('Откройте на портале форму за скопированный месяц');
        if (periodError === 'semester') throw new Error('Семестр в данных не совпадает с семестром открытой формы');
        const {matches, hidden, hiddenHours} = workloadMatches(payload.lines, report.cells, payload.semester);
        current = {scope: report.scope, matches, selected: matches.map(match => match.suggested)};
        if (hidden) preview.append(element('p', hiddenSummary(hidden, hiddenHours)));
        matches.forEach(({line, choices, hasColumn}, index) => {
          const row = element('div');
          row.append(element('strong', line.discipline));
          const detail = [columns[line.column], line.groups.join(', '), line.hours + ' ч.'].filter(Boolean);
          row.append(element('div', detail.join(' · ')));
          if (choices.length) {
            const select = element('select');
            select.setAttribute('aria-label', 'Строка портала для ' + line.discipline);
            select.append(option('', 'Пропустить'));
            choices.forEach((cell, position) => select.append(option(cell.key,
              (position + 1) + ' · ' + cell.specialty + ' · ' + cell.appointment)));
            select.value = current.selected[index];
            select.addEventListener('change', () => {
              current.selected[index] = select.value;
              renderChanges();
            });
            row.append(select);
          } else {
            row.append(element('div', hasColumn ? 'Подходящие поля уже заполнены' : 'В форме нет поля для этого вида занятий'));
          }
          preview.append(row);
        });
        renderChanges();
      } catch (error) {
        status.textContent = error.message;
      }
    }

    function apply() {
      if (!current?.changes.length || filled) return;
      try {
        const {scope, changes} = current;
        const result = run('fill', {scope, changes: Object.fromEntries(
          changes.map(({cell, before, after}) => [cell.key, {before, after}])
        )});
        if (!result.filled) {
          status.textContent = result.error === 'value'
            ? 'Не удалось перенести все часы, проверьте значения в форме'
            : 'Форма изменилась или содержит несохранённые правки, проверьте часы снова';
          fill.disabled = true;
          return;
        }
        filled = true;
        reset();
      } catch {
        status.textContent = 'Не удалось заполнить форму, проверьте значения на портале';
        fill.disabled = true;
      }
    }
  }

  function load() {
    if (document.getElementById(panelId) || document.getElementById(loaderId)) return;
    const entry = new URL(document.currentScript.src);
    const asset = new URL('../assets/assets/portal/workload.js', entry);
    asset.search = entry.search;
    const script = element('script');
    script.id = loaderId;
    script.src = asset.href;
    script.referrerPolicy = 'no-referrer';
    const unavailable = () => alert('Не удалось загрузить помощник заполнения формы');
    script.onload = () => {
      script.remove();
      const run = window.volgatechWorkload;
      if (typeof run === 'function') {
        workloadPanel((action, request) => JSON.parse(run(action, request)));
      } else {
        unavailable();
      }
    };
    script.onerror = () => {
      script.remove();
      unavailable();
    };
    document.head.append(script);
  }

  if (typeof document === 'undefined' && typeof module !== 'undefined') {
    module.exports = {workloadName, workloadMatches, workloadChanges, workloadPeriodError};
  } else if (location.origin === 'https://portal.volgatech.net') {
    load();
  }
})();
