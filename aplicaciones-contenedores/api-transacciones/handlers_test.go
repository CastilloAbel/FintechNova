package main

import (
 "encoding/json"
 "net/http"
 "net/http/httptest"
 "testing"
)

func TestResponderJSON(t *testing.T) {
 w := httptest.NewRecorder()
 responderJSON(w, http.StatusOK, map[string]string{"status": "ok", "servicio": "api-transacciones"})
 if w.Code != http.StatusOK { t.Fatalf("status = %d", w.Code) }
 var body map[string]string
 if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil { t.Fatal(err) }
 if body["status"] != "ok" || body["servicio"] != "api-transacciones" { t.Fatalf("respuesta = %v", body) }
}
