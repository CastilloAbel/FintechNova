const test = require('node:test');
const assert = require('node:assert/strict');
const app = require('../src/server');
const http = require('node:http');

async function consultar(ruta) {
  const server = http.createServer(app);
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  try {
    const port = server.address().port;
    const response = await fetch(`http://127.0.0.1:${port}${ruta}`);
    return { status: response.status, body: await response.json() };
  } finally {
    await new Promise(resolve => server.close(resolve));
  }
}

test('GET / responde estado OK', async () => {
  const r = await consultar('/');
  assert.equal(r.status, 200);
  assert.deepEqual(r.body, { status: 'ok', servicio: 'api-pagos' });
});

test('ruta inexistente responde 404', async () => {
  const r = await consultar('/ruta-que-no-existe');
  assert.equal(r.status, 404);
  assert.deepEqual(r.body, { error: 'Not Found' });
});
