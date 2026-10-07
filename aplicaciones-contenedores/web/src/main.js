import './style.css';

// Un solo front (Vite) para las 5 APIs. Todas las llamadas van a "/api/<servicio>/..."
// -> en produccion NGINX reenvia cada prefijo al contenedor que corresponde (ver nginx.conf);
// en desarrollo lo hace el proxy de Vite (ver vite.config.js).
const ENTIDADES = [
  {
    key: 'clientes',
    titulo: 'Clientes',
    campos: [
      { name: 'nombre', label: 'Nombre', type: 'text' },
      { name: 'email', label: 'Email', type: 'email' },
      { name: 'dni', label: 'DNI', type: 'text' },
    ],
  },
  {
    key: 'pagos',
    titulo: 'Pagos',
    campos: [
      { name: 'monto_ars', label: 'Monto (ARS)', type: 'number' },
      { name: 'medio_pago', label: 'Medio de pago', type: 'text' },
    ],
    soloLectura: ['monto_usd'],
  },
  {
    key: 'facturas',
    titulo: 'Facturas',
    campos: [
      { name: 'numero', label: 'Numero', type: 'text' },
      { name: 'monto', label: 'Monto', type: 'number' },
      { name: 'clienteId', label: 'ID Cliente', type: 'number' },
      { name: 'fechaEmision', label: 'Fecha emision', type: 'date' },
    ],
  },
  {
    key: 'transacciones',
    titulo: 'Transacciones',
    campos: [
      { name: 'origen_ip', label: 'IP de origen', type: 'text' },
      { name: 'monto', label: 'Monto', type: 'number' },
      { name: 'tipo', label: 'Tipo', type: 'text' },
    ],
    soloLectura: ['pais'],
  },
  {
    key: 'tarjetas',
    titulo: 'Tarjetas',
    campos: [
      { name: 'alias', label: 'Alias', type: 'text' },
      { name: 'titular', label: 'Titular', type: 'text' },
      { name: 'tipo', label: 'Tipo (credito/debito)', type: 'text' },
      { name: 'limite', label: 'Limite', type: 'number' },
    ],
  },
];

const app = document.querySelector('#app');

const DESCRIPCIONES = {
  clientes: 'Administra los perfiles y datos de tus clientes.',
  pagos: 'Registra pagos y consulta su conversión automática a dólares.',
  facturas: 'Consulta y organiza las facturas emitidas a tus clientes.',
  transacciones: 'Monitorea movimientos y su ubicación de origen.',
  tarjetas: 'Gestiona tarjetas, titulares y límites disponibles.',
};

function crearNav() {
  const nav = document.createElement('nav');
  nav.setAttribute('aria-label', 'Secciones de microservicios');
  nav.className = 'mb-6 flex gap-2 overflow-x-auto rounded-2xl border border-surface-700/70 bg-surface-800/70 p-2 shadow-lg shadow-black/10';
  ENTIDADES.forEach((entidad, i) => {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.dataset.key = entidad.key;
    btn.setAttribute('aria-pressed', String(i === 0));
    btn.className = 'flex shrink-0 items-center gap-2.5 rounded-xl px-4 py-3 text-sm font-semibold text-surface-300 transition hover:bg-surface-700/70 hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary-400';
    if (i === 0) {
      btn.classList.add('bg-primary-500/15', 'text-primary-300', 'ring-1', 'ring-inset', 'ring-primary-400/30');
    }
    const icon = document.createElement('span');
    icon.className = 'grid size-7 place-items-center rounded-lg bg-surface-700 text-xs font-bold text-primary-300';
    icon.textContent = entidad.titulo.slice(0, 1);
    const label = document.createElement('span');
    label.textContent = entidad.titulo;
    btn.append(icon, label);
    btn.addEventListener('click', () => mostrarSeccion(entidad.key));
    nav.appendChild(btn);
  });
  return nav;
}

function mostrarSeccion(key) {
  document.querySelectorAll('main section').forEach((s) => {
    s.hidden = s.dataset.key !== key;
  });
  document.querySelectorAll('nav button').forEach((b) => {
    const activo = b.dataset.key === key;
    b.setAttribute('aria-pressed', String(activo));
    b.classList.toggle('bg-primary-500/15', activo);
    b.classList.toggle('text-primary-300', activo);
    b.classList.toggle('ring-1', activo);
    b.classList.toggle('ring-inset', activo);
    b.classList.toggle('ring-primary-400/30', activo);
  });
}

function crearSeccion(entidad) {
  const section = document.createElement('section');
  section.dataset.key = entidad.key;
  section.hidden = entidad.key !== ENTIDADES[0].key;
  section.className = 'rounded-3xl border border-surface-700/70 bg-surface-800/80 p-5 shadow-2xl shadow-black/20 backdrop-blur sm:p-8';

  const sectionHeader = document.createElement('div');
  sectionHeader.className = 'mb-7 flex flex-wrap items-start justify-between gap-4';
  const headingGroup = document.createElement('div');
  const eyebrow = document.createElement('p');
  eyebrow.className = 'mb-2 text-xs font-bold uppercase tracking-[0.2em] text-primary-400';
  eyebrow.textContent = 'Microservicio';
  const h2 = document.createElement('h2');
  h2.className = 'text-2xl font-bold tracking-tight text-white sm:text-3xl';
  h2.textContent = entidad.titulo;
  const description = document.createElement('p');
  description.className = 'mt-2 max-w-2xl text-sm leading-6 text-surface-400 sm:text-base';
  description.textContent = DESCRIPCIONES[entidad.key];
  headingGroup.append(eyebrow, h2, description);

  const count = document.createElement('span');
  count.dataset.count = '';
  count.className = 'inline-flex items-center gap-2 rounded-full border border-surface-700 bg-surface-900/70 px-3.5 py-2 text-xs font-semibold text-surface-300';
  count.textContent = '… registros';
  sectionHeader.append(headingGroup, count);
  section.appendChild(sectionHeader);

  const form = document.createElement('form');
  form.className = 'mb-6 grid grid-cols-1 items-end gap-4 rounded-2xl border border-surface-700/70 bg-surface-900/45 p-4 sm:grid-cols-2 sm:p-5 xl:grid-cols-4';
  entidad.campos.forEach((campo) => {
    const field = document.createElement('div');
    field.className = 'min-w-0';
    const label = document.createElement('label');
    label.htmlFor = `${entidad.key}-${campo.name}`;
    label.className = 'mb-2 block text-xs font-semibold tracking-wide text-surface-300';
    label.textContent = campo.label;
    const input = document.createElement('input');
    input.type = campo.type;
    input.name = campo.name;
    input.id = `${entidad.key}-${campo.name}`;
    input.placeholder = campo.type === 'date' ? '' : `Ingresá ${campo.label.toLowerCase()}`;
    input.required = true;
    input.className = 'min-h-11 w-full rounded-xl border border-surface-600 bg-surface-800 px-3.5 py-2.5 text-sm text-white placeholder:text-surface-500 transition focus:border-primary-400 focus:outline-none focus:ring-4 focus:ring-primary-500/10';
    field.append(label, input);
    form.appendChild(field);
  });
  const submit = document.createElement('button');
  submit.type = 'submit';
  submit.className = 'inline-flex min-h-11 items-center justify-center gap-2 rounded-xl bg-primary-500 px-5 py-2.5 text-sm font-bold text-surface-950 shadow-lg shadow-primary-950/40 transition hover:bg-primary-400 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary-300 focus-visible:ring-offset-2 focus-visible:ring-offset-surface-900 disabled:cursor-wait disabled:opacity-60';
  submit.innerHTML = '<span aria-hidden="true">＋</span><span>Agregar registro</span>';
  form.appendChild(submit);
  section.appendChild(form);

  const notice = document.createElement('p');
  notice.dataset.notice = '';
  notice.setAttribute('role', 'status');
  notice.setAttribute('aria-live', 'polite');
  notice.hidden = true;
  section.appendChild(notice);

  const columnas = ['id', ...entidad.campos.map((c) => c.name), ...(entidad.soloLectura || [])];

  const tableContainer = document.createElement('div');
  tableContainer.className = 'overflow-x-auto rounded-2xl border border-surface-700/70';
  const table = document.createElement('table');
  table.className = 'w-full min-w-max border-collapse text-left text-sm';
  const thead = document.createElement('thead');
  thead.className = 'bg-surface-900/70';
  const trHead = document.createElement('tr');
  [...columnas, 'Acciones'].forEach((c) => {
    const th = document.createElement('th');
    th.className = 'whitespace-nowrap px-4 py-3.5 text-[11px] font-bold uppercase tracking-wider text-surface-400 sm:px-5';
    th.scope = 'col';
    th.textContent = c ? obtenerEtiquetaColumna(entidad, c) : '';
    trHead.appendChild(th);
  });
  thead.appendChild(trHead);
  table.appendChild(thead);
  const tbody = document.createElement('tbody');
  tbody.className = 'divide-y divide-surface-700/70';
  table.appendChild(tbody);
  tableContainer.appendChild(table);
  section.appendChild(tableContainer);

  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    const datos = Object.fromEntries(new FormData(form).entries());
    // Validar IP en Transacciones
    if (entidad.key === 'transacciones') {
      const ip = datos.origen_ip.trim();

      const partes = ip.split('.');
      const ipValida =
        partes.length === 4 &&
        partes.every((parte) => {
          const numero = Number(parte);
          return parte !== '' &&
            Number.isInteger(numero) &&
            numero >= 0 &&
            numero <= 255;
        });

      if (!ipValida) {
        alert('Ingresá una dirección IPv4 válida. Ejemplo: 8.8.4.4');
        return;
      }
    }
    entidad.campos.forEach((campo) => {
      if (campo.type === 'number') datos[campo.name] = Number(datos[campo.name]);
    });
    submit.disabled = true;
    try {
      const response = await fetch(`/api/${entidad.key}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(datos),
      });
      if (!response.ok) throw new Error(`El servidor respondió HTTP ${response.status}.`);
      form.reset();
      mostrarAviso(section, 'Registro agregado correctamente.', 'success');
      await cargar(entidad, tbody, columnas);
    } catch (error) {
      mostrarAviso(section, `No se pudo agregar el registro. ${error.message}`, 'error');
    } finally {
      submit.disabled = false;
    }
  });

  cargar(entidad, tbody, columnas, section);
  return section;
}

function obtenerEtiquetaColumna(entidad, columna) {
  const etiquetas = { id: 'ID', monto_usd: 'Monto USD', pais: 'País' };
  return etiquetas[columna] || entidad.campos.find((campo) => campo.name === columna)?.label || columna;
}

function mostrarAviso(section, mensaje, tipo) {
  const notice = section.querySelector('[data-notice]');
  notice.hidden = false;
  notice.className = tipo === 'error'
    ? 'mb-5 rounded-xl border border-rose-400/20 bg-rose-400/10 px-4 py-3 text-sm text-rose-200'
    : 'mb-5 rounded-xl border border-emerald-400/20 bg-emerald-400/10 px-4 py-3 text-sm text-emerald-200';
  notice.textContent = mensaje;
}

async function cargar(entidad, tbody, columnas, section) {
  tbody.replaceChildren();
  const loading = document.createElement('tr');
  const loadingCell = document.createElement('td');
  loadingCell.colSpan = columnas.length + 1;
  loadingCell.className = 'px-5 py-10 text-center text-sm text-surface-400';
  loadingCell.textContent = 'Cargando registros…';
  loading.appendChild(loadingCell);
  tbody.appendChild(loading);

  try {
    const res = await fetch(`/api/${entidad.key}`);
    if (!res.ok) throw new Error(`El servidor respondió HTTP ${res.status}.`);
    const items = await res.json();
    if (!Array.isArray(items)) throw new Error('La respuesta del servicio no tiene el formato esperado.');
    tbody.replaceChildren();
    section.querySelector('[data-count]').textContent = `${items.length} ${items.length === 1 ? 'registro' : 'registros'}`;

    if (items.length === 0) {
      const emptyRow = document.createElement('tr');
      const emptyCell = document.createElement('td');
      emptyCell.colSpan = columnas.length + 1;
      emptyCell.className = 'px-5 py-12 text-center text-sm text-surface-400';
      emptyCell.textContent = 'Todavía no hay registros. Completá el formulario para agregar el primero.';
      emptyRow.appendChild(emptyCell);
      tbody.appendChild(emptyRow);
      return;
    }

    items.forEach((item) => {
      const tr = document.createElement('tr');
      tr.className = 'transition-colors hover:bg-surface-700/30';
      columnas.forEach((col) => {
        const td = document.createElement('td');
        td.className = col === 'id'
          ? 'whitespace-nowrap px-4 py-4 font-semibold text-primary-300 sm:px-5'
          : 'whitespace-nowrap px-4 py-4 text-surface-200 sm:px-5';
        td.textContent = item[col] ?? '—';
        tr.appendChild(td);
      });
      const tdBorrar = document.createElement('td');
      tdBorrar.className = 'px-4 py-3.5 sm:px-5';
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.textContent = 'Borrar';
      btn.setAttribute('aria-label', `Borrar registro ${item.id}`);
      btn.className = 'rounded-lg border border-rose-400/20 bg-rose-400/5 px-3 py-2 text-xs font-semibold text-rose-200 transition hover:border-rose-400/40 hover:bg-rose-400/15 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-rose-300';
      btn.addEventListener('click', async () => {
        btn.disabled = true;
        try {
          const response = await fetch(`/api/${entidad.key}/${item.id}`, { method: 'DELETE' });
          if (!response.ok) throw new Error(`El servidor respondió HTTP ${response.status}.`);
          mostrarAviso(section, 'Registro eliminado correctamente.', 'success');
          await cargar(entidad, tbody, columnas, section);
        } catch (error) {
          btn.disabled = false;
          mostrarAviso(section, `No se pudo borrar el registro. ${error.message}`, 'error');
        }
      });
      tdBorrar.appendChild(btn);
      tr.appendChild(tdBorrar);
      tbody.appendChild(tr);
    });
  } catch (error) {
    section.querySelector('[data-count]').textContent = 'Sin conexión';
    tbody.replaceChildren();
    const errorRow = document.createElement('tr');
    const errorCell = document.createElement('td');
    errorCell.colSpan = columnas.length + 1;
    errorCell.className = 'px-5 py-10 text-center text-sm text-rose-200';
    errorCell.textContent = `No se pudieron cargar los registros. ${error.message}`;
    errorRow.appendChild(errorCell);
    tbody.appendChild(errorRow);
  }
}

function render() {
  const shell = document.createElement('div');
  shell.className = 'mx-auto w-full max-w-6xl px-4 py-6 sm:px-6 sm:py-10 lg:px-8';
  const encabezado = document.createElement('header');
  encabezado.className = 'mb-6 overflow-hidden rounded-3xl border border-surface-700/70 bg-surface-800/80 p-5 shadow-2xl shadow-black/20 backdrop-blur sm:p-8';

  const encabezadoSuperior = document.createElement('div');
  encabezadoSuperior.className = 'flex flex-wrap items-center justify-between gap-5';

  const info = document.createElement('div');
  info.className = 'flex items-center gap-4';
  const logo = document.createElement('span');
  logo.className = 'grid size-12 shrink-0 place-items-center rounded-2xl bg-gradient-to-br from-primary-300 to-primary-600 text-lg font-black text-surface-950 shadow-lg shadow-primary-950/40';
  logo.textContent = 'FN';
  const brand = document.createElement('div');

  const titulo = document.createElement('h1');
  titulo.className = 'gradient-text text-2xl font-extrabold tracking-tight sm:text-3xl';
  titulo.textContent = 'FinTech Nova';

  const subtitulo = document.createElement('p');
  subtitulo.className = 'mt-1 text-sm text-surface-400 sm:text-base';
  subtitulo.textContent = 'Panel de Microservicios';

  brand.append(titulo, subtitulo);
  info.append(logo, brand);

  const badge = document.createElement('span');
  badge.className = 'inline-flex items-center gap-2 rounded-full border border-primary-400/20 bg-primary-400/10 px-3.5 py-2 text-xs font-bold tracking-wider text-primary-200';
  badge.innerHTML = '<span class="size-1.5 rounded-full bg-primary-400"></span> GRUPO 19 · 5 SERVICIOS';

  encabezadoSuperior.appendChild(info);
  encabezadoSuperior.appendChild(badge);

  const integrantes = document.createElement('div');
  integrantes.className = 'mt-6 flex flex-wrap gap-x-8 gap-y-3 border-t border-surface-700/70 pt-5 text-sm text-surface-400';
  integrantes.innerHTML = '<span><strong class="font-semibold text-surface-200">Camila Gea</strong><span class="mx-2 text-surface-600">/</span>Legajo 82327</span><span><strong class="font-semibold text-surface-200">Abel Castillo</strong><span class="mx-2 text-surface-600">/</span>Legajo 90322</span>';

  encabezado.appendChild(encabezadoSuperior);
  encabezado.appendChild(integrantes);

  shell.appendChild(encabezado);
  shell.appendChild(crearNav());

  const main = document.createElement('main');
  main.setAttribute('aria-label', 'Administración de microservicios');
  ENTIDADES.forEach((entidad) => main.appendChild(crearSeccion(entidad)));
  shell.appendChild(main);

  const footer = document.createElement('footer');
  footer.className = 'py-7 text-center text-xs text-surface-500';
  footer.textContent = 'FinTech Nova · Plataforma de servicios financieros';
  shell.appendChild(footer);
  app.className = 'min-h-screen';
  app.appendChild(shell);
}

render();
