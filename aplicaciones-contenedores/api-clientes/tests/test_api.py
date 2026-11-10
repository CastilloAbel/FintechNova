import unittest
from unittest.mock import MagicMock, patch

from main import app


class ClientesApiTests(unittest.TestCase):
    def setUp(self):
        app.config["TESTING"] = True
        self.client = app.test_client()

    def test_health(self):
        response = self.client.get("/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json(), {"status": "ok", "servicio": "api-clientes"})

    @patch("main.mysql.connect")
    def test_listar_clientes(self, mock_connect):
        cursor = MagicMock()
        cursor.fetchall.return_value = [{"id": 1, "nombre": "Cliente de prueba"}]
        mock_connect.return_value.cursor.return_value = cursor
        response = self.client.get("/clientes")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json()[0]["nombre"], "Cliente de prueba")
        cursor.execute.assert_called_once_with("SELECT * FROM clientes")

    @patch("main.mysql.connect")
    def test_cliente_inexistente(self, mock_connect):
        cursor = MagicMock()
        cursor.fetchone.return_value = None
        mock_connect.return_value.cursor.return_value = cursor
        response = self.client.get("/clientes/999")
        self.assertEqual(response.status_code, 404)
        self.assertEqual(response.get_json()["error"], "Cliente no encontrado")


if __name__ == "__main__":
    unittest.main()
