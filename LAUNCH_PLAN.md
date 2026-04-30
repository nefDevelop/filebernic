
### A. Configuración de Producción

- **API Keys**: En `main.lua`, `config.thegamesdb_apikey` está vacío.
    - *Solución*: Implementar un teclado virtual para que el usuario introduzca su propia API Key, o incluir una "default" con límites claros.


- **Assets Gráficos para Tiendas/Discord**:
    - **Banner**: 1280x720px o similar para posts en redes/Discord.
    - **Screenshots**: Capturas limpias de la interfaz (Lista, Grid, Detalles).
    - **Logo**: Versión vectorial o alta resolución del logo de FileBernic.

## 4. Mejoras Técnicas Sugeridas (Quick Wins)


1.  **Validación de Actualizaciones**:
    - ¿Cómo actualizarán los usuarios? Si no hay OTA (Over-The-Air), dejar claro en la App que deben bajar la nueva versión manualmente.

## 5. Plan de Acción (Checklist)

### Fase 1: Limpieza de Código
- [ ] Cambiar `DEBUG = 0` en `main.lua`.
- [ ] Verificar que `thegamesdb_apikey` se maneje con gracia si está vacía (mostrar mensaje al usuario).
- [ ] Crear archivo `LICENSE`.


- [ ] Tomar 3-4 screenshots finales.

### Fase 4: Lanzamiento
- [ ] Publicar release en GitHub.
- [ ] Anunciar en canales de muOS.
