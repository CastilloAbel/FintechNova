package ar.edu.utn.frc.devops.facturas;

import org.junit.jupiter.api.Test;
import java.util.List;
import java.util.Optional;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class FacturaControllerTest {
    @Test
    void listarDevuelveFacturasDelRepositorio() {
        FacturaRepository repo = mock(FacturaRepository.class);
        when(repo.findAll()).thenReturn(List.of(new Factura()));
        var resultado = new FacturaController(repo).listar();
        assertEquals(1, resultado.size());
        verify(repo).findAll();
    }

    @Test
    void facturaInexistenteDevuelve404() {
        FacturaRepository repo = mock(FacturaRepository.class);
        when(repo.findById(999L)).thenReturn(Optional.empty());
        var respuesta = new FacturaController(repo).obtener(999L);
        assertEquals(404, respuesta.getStatusCode().value());
    }
}
