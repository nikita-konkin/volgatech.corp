((action, request) => {
  const portal = 'https://portal.volgatech.net';
  const pageName = 'нагрузка на первую половину дня.aspx';
  const pagePath = url => url.pathname.replace(/&authresend[0-9a-f]+$/i, '');
  const isWorkloadPage = url => url.origin === portal &&
    /^\/my\/personal\/[^/]+\/sitepages\/[^/]+$/i.test(pagePath(url)) &&
    decodeURIComponent(pagePath(url)).split('/').pop().toLowerCase() === pageName;
  const reply = data => JSON.stringify(data);
  const fail = error => reply({error});
  const clean = text => text.trim().replace(/\s+/g, ' ');

  if (location.origin !== portal) return fail('page');
  if (action === 'link') {
    if (pagePath(location).toLowerCase() !== '/my/person.aspx') return fail('page');
    const link = Array.from(document.links).find(link => isWorkloadPage(new URL(link.href)));
    return reply({url: link ? link.href : null});
  }
  if (!isWorkloadPage(location)) return fail('page');
  const bridge = window.volgatechWorkload ??= {revision: 0, receipt: null};
  if (action === 'receipt') return reply(bridge.receipt ?? {});

  const postback = window.Sys?.WebForms?.PageRequestManager?.getInstance();
  if (postback?.get_isInAsyncPostBack()) return fail('loading');
  if (!bridge.watching && postback) {
    postback.add_endRequest(() => bridge.revision++);
    bridge.watching = true;
  }

  const dropdown = name => {
    const root = document.querySelector('.RadDropDownList[id$="_' + name + '"]');
    return root && window.$find?.(root.id);
  };
  const option = item => ({label: clean(item.get_text()), value: item.get_value()});
  const read = list => {
    const items = list?.get_items();
    const selected = list?.get_selectedItem();
    if (!items || !selected) return null;
    return {
      selected: option(selected),
      options: Array.from({length: items.get_count()}, (_, i) => items.getItem(i))
        .filter(item => item.get_enabled()).map(option)
    };
  };
  const lists = {
    person: dropdown('ddlPerson'),
    month: dropdown('ddlMonth'),
    year: dropdown('ddlStudyYear'),
    department: dropdown('ddlKafedra')
  };
  const filters = Object.fromEntries(Object.entries(lists).map(([k, list]) => [k, read(list)]));
  if (Object.values(filters).some(filter => filter === null)) return fail('loading');
  const edit = document.querySelector('a[id$="_btnEdit"]');
  const save = document.querySelector('a[id$="_btnSave"]');
  const scope = JSON.stringify([pagePath(location),
    ...Object.values(filters).map(filter => filter.selected)]);
  const form = document.getElementById('aspnetForm');
  const target = form && new URL(form.action);
  const validForm = target && isWorkloadPage(target) &&
    pagePath(target) === pagePath(location) &&
    form.method.toLowerCase() === 'post' && form.elements.__VIEWSTATE;
  const postEvent = (name, argument) => {
    form.elements.__EVENTTARGET.value = name;
    form.elements.__EVENTARGUMENT.value = argument;
    setTimeout(() => HTMLFormElement.prototype.submit.call(form), 50);
    return reply({started: true});
  };

  if (action === 'info') return reply({filters, mode: save ? 'edit' : edit ? 'view' : '',
    revision: String(performance.timeOrigin) + ':' + bridge.revision});
  if (action === 'select') {
    const controlNames = {year: 'ddlStudyYear', month: 'ddlMonth', department: 'ddlKafedra'};
    const control = controlNames[request.filter];
    if (!control) return fail('grid');
    const items = lists[request.filter].get_items();
    for (let i = 0; i < items.get_count(); i++) {
      const item = items.getItem(i);
      if (item.get_value() === request.value && item.get_enabled()) {
        if (!validForm) return fail('grid');
        // The legacy Web Forms submit wrapper inspects its callers. Capture
        // the native dropdown event before it enters that wrapper.
        let event = null;
        const original = window.WebForm_DoPostBackWithOptions;
        try {
          window.WebForm_DoPostBackWithOptions = options => { event = options; };
          item.select();
        } finally {
          window.WebForm_DoPostBackWithOptions = original;
        }
        if (!event?.clientSubmit || !event.eventTarget.endsWith('$' + control)) {
          return fail('grid');
        }
        return postEvent(event.eventTarget, event.eventArgument);
      }
    }
    return fail('changed');
  }
  if (action === 'edit') {
    const command = /^javascript:WebForm_DoPostBackWithOptions\(new WebForm_PostBackOptions\("([^"]+\$btnEdit)", "", true, "", "", false, true\)\)$/
      .exec(edit?.getAttribute('href') ?? '');
    return validForm && command ? postEvent(command[1], '') : fail('grid');
  }

  const tables = document.querySelectorAll('table.rgMasterTable[id*="_radGridEdit_"]');
  if (tables.length !== 1 || !save) return fail('grid');
  const table = tables[0];
  const grid = window.$find?.(table.id.replace(/_ctl00$/, ''));
  const batch = grid?.get_batchEditingManager();
  if (!batch || !table.tBodies[0] || !table.rows[0]) return fail('grid');
  if (batch.get_currentlyEditedCell() || batch.get_currentlyEditedRow()) return fail('changed');

  let index = 0;
  const columns = new Map();
  for (const header of table.rows[0].cells) {
    const match = /(HoursAuditLec|HoursAuditLab|HoursAuditPract|HoursExam|HoursTest|HoursConsultExam|HoursStudyPract)\d+_MultiHeader\d+$/.exec(header.id);
    if (match && header.colSpan === 1) columns.set(match[1], index);
    index += header.colSpan;
  }
  if (table.tBodies[0].querySelector('.rgNoRecords') &&
      !table.tBodies[0].querySelector('.hourspps-item')) {
    return action === 'inspect' ? reply({scope, filters, cells: []}) : fail('changed');
  }
  if (columns.size === 0) return fail('grid');

  const headings = ['', '', '', ''];
  const prefixes = ['Тип:', 'Семестр:', 'Дисциплина:', 'Специальность:'];
  const cells = new Map();
  const hundredths = cell => {
    const raw = batch.getCellValue(cell);
    if (raw == null) return null;
    const text = String(raw).replace(/\s/g, '').replace(',', '.');
    if (text === '') return 0;
    const amount = Math.round(Number(text) * 100);
    return /^\d+(?:\.\d{1,2})?$/.test(text) && Number.isSafeInteger(amount) ? amount : null;
  };
  for (const row of table.tBodies[0].rows) {
    const group = /\bhourspps-group-([1-4])\b/.exec(row.className);
    if (group) {
      const level = Number(group[1]) - 1;
      const title = clean(row.querySelector('.rgGroupHeaderText')?.textContent ?? '');
      headings.fill('', level);
      if (title.startsWith(prefixes[level])) {
        headings[level] = clean(title.slice(prefixes[level].length));
      }
    } else if (row.classList.contains('hourspps-item')) {
      if (!row.id || headings.some(title => !title) || row.cells.length !== index) {
        return fail('grid');
      }
      const [appointment, semester, discipline, specialty] = headings;
      const rowKey = JSON.stringify([row.id, ...headings]);
      for (const [column, position] of columns) {
        const cell = row.cells[position];
        if (cell.classList.contains('readonly')) continue;
        const amount = hundredths(cell);
        if (amount === null) return fail('grid');
        const key = JSON.stringify([rowKey, column]);
        if (cells.has(key)) return fail('grid');
        cells.set(key, {cell, data: {
          key, rowKey, appointment, semester, discipline, specialty, column, amount
        }});
      }
    }
  }

  if (action === 'inspect') {
    return reply({scope, filters, cells: Array.from(cells.values(), entry => entry.data)});
  }
  if (action !== 'submit' || request.scope !== scope || bridge.receipt?.state === 'pending') {
    return fail('changed');
  }
  const pending = Object.entries(request.changes);
  if (!pending.length || !validForm ||
      grid.ClientSettings.PostBackFunction.trim() !== "__doPostBack('{0}','{1}')" ||
      batch.hasChanges(grid.get_masterTableView())) {
    return fail('changed');
  }
  for (const [key, change] of pending) {
    if (cells.get(key)?.data.amount !== change.before || !Number.isSafeInteger(change.after) ||
        change.after < 0 || change.before === change.after) return fail('changed');
  }
  for (const [key, change] of pending) {
    const {cell} = cells.get(key);
    batch.changeCellValue(cell, change.after / 100);
    if (hundredths(cell) !== change.after) return fail('value');
  }

  // Telerik produces the portal's event argument. Capture it without running
  // the browser postback, then send the authenticated Web Forms request.
  let event = null;
  const original = window.__doPostBack;
  try {
    window.__doPostBack = (name, argument) => { event = {name, argument}; };
    batch.saveChanges(grid.get_masterTableView());
  } finally {
    window.__doPostBack = original;
  }
  if (!event || event.name !== grid.UniqueID ||
      !/^FireCommand:[^;]+;BatchEdit;u\(/.test(event.argument)) return fail('grid');
  const body = new URLSearchParams(new FormData(form));
  body.set('__EVENTTARGET', event.name);
  body.set('__EVENTARGUMENT', event.argument);
  const receipt = bridge.receipt = {id: request.id, state: 'pending'};
  const abort = new AbortController();
  const timeout = setTimeout(() => abort.abort(), 18000);
  fetch(target.href, {
    method: 'POST', credentials: 'same-origin', cache: 'no-store', body, signal: abort.signal
  }).then(response => {
    receipt.state = response.ok && isWorkloadPage(new URL(response.url)) ? 'received' : 'unknown';
  }).catch(() => {
    receipt.state = 'unknown';
  }).finally(() => clearTimeout(timeout));
  return reply({started: true});
})
